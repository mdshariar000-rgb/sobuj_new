<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Expression;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use RuntimeException;

/**
 * Gives a model an exact `base_location` and a privacy-preserving `fuzzy_location`,
 * both native MySQL 8 `POINT SRID 4326` columns.
 *
 * MySQL ties WKT axis order to the SRS definition, and SRID 4326 (WGS84) natively
 * parses `POINT(x y)` as (latitude, longitude) — the opposite of the (longitude,
 * latitude) = (X, Y) convention used by GeoJSON, Google Maps, and most of the rest of
 * this codebase. To avoid that footgun, every point built here is pinned to
 * (longitude, latitude) order via the explicit `axis-order=long-lat` option on
 * ST_GeomFromText(), so ST_X()/ST_Y() and ST_Distance_Sphere() consistently agree:
 * ST_X() = longitude, ST_Y() = latitude. Any raw spatial SQL added elsewhere in the
 * app MUST follow this same convention.
 *
 * Consumers must expose two NOT NULL POINT SRID 4326 columns: `base_location` and
 * `fuzzy_location`, with a spatial index on `fuzzy_location` (InnoDB rejects NULL in a
 * spatially-indexed column outright, so both must always hold a real value).
 */
trait HasFuzzyLocation
{
    private const EARTH_RADIUS_METERS = 6_371_000.0;

    private const MIN_FUZZ_OFFSET_METERS = 500.0;

    private const MAX_FUZZ_OFFSET_METERS = 1000.0;

    /**
     * Set the exact location and derive a fresh fuzzed location from it.
     *
     * Does not persist — call save() (or update()) as usual afterwards.
     */
    public function setLocation(float $latitude, float $longitude): static
    {
        self::assertValidCoordinates($latitude, $longitude);

        $fuzzy = self::applyFuzzyOffset($latitude, $longitude);

        $this->setAttribute('base_location', self::toPointExpression($latitude, $longitude));
        $this->setAttribute('fuzzy_location', self::toPointExpression($fuzzy['latitude'], $fuzzy['longitude']));

        return $this;
    }

    /**
     * Re-roll the fuzzy offset from the currently stored exact location and persist it
     * immediately. Use periodically so a fixed fuzzy point can't be triangulated over
     * time into the real location.
     */
    public function refreshFuzzyLocation(): static
    {
        $exact = static::query()
            ->whereKey($this->getKey())
            ->selectRaw('ST_Y(base_location) as latitude, ST_X(base_location) as longitude')
            ->first();

        if (! $exact || $exact->latitude === null || $exact->longitude === null) {
            throw new RuntimeException(
                'Cannot refresh fuzzy_location: no base_location is set for this record.'
            );
        }

        $fuzzy = self::applyFuzzyOffset((float) $exact->latitude, (float) $exact->longitude);
        $pointSql = self::toPointExpression($fuzzy['latitude'], $fuzzy['longitude']);

        static::query()->whereKey($this->getKey())->update(['fuzzy_location' => $pointSql]);

        $this->setAttribute('fuzzy_location', $pointSql);

        return $this;
    }

    /**
     * Compute a random offset point between 500m and 1000m from the given coordinates.
     *
     * The offset distance is sampled uniformly over the *area* of the [min, max]
     * annulus (not linearly over the radius) so points don't cluster near the 500m
     * inner edge, which would otherwise leak a usable minimum-distance signal.
     *
     * @return array{latitude: float, longitude: float}
     */
    public static function applyFuzzyOffset(float $latitude, float $longitude): array
    {
        self::assertValidCoordinates($latitude, $longitude);

        return self::destinationPoint(
            $latitude,
            $longitude,
            self::randomFuzzDistanceMeters(),
            self::randomBearingRadians(),
        );
    }

    private static function randomFuzzDistanceMeters(): float
    {
        $u = random_int(0, 1_000_000) / 1_000_000;
        $minSq = self::MIN_FUZZ_OFFSET_METERS ** 2;
        $maxSq = self::MAX_FUZZ_OFFSET_METERS ** 2;

        return sqrt($u * ($maxSq - $minSq) + $minSq);
    }

    private static function randomBearingRadians(): float
    {
        return (random_int(0, 1_000_000) / 1_000_000) * 2 * M_PI;
    }

    /**
     * Great-circle destination point given a start point, distance, and bearing
     * (spherical Earth model — standard direct geodesic formula).
     *
     * @return array{latitude: float, longitude: float}
     */
    private static function destinationPoint(
        float $latitude,
        float $longitude,
        float $distanceMeters,
        float $bearingRadians
    ): array {
        $angularDistance = $distanceMeters / self::EARTH_RADIUS_METERS;
        $latRad = deg2rad($latitude);
        $lngRad = deg2rad($longitude);

        $destLatRad = asin(
            sin($latRad) * cos($angularDistance)
            + cos($latRad) * sin($angularDistance) * cos($bearingRadians)
        );

        $destLngRad = $lngRad + atan2(
            sin($bearingRadians) * sin($angularDistance) * cos($latRad),
            cos($angularDistance) - sin($latRad) * sin($destLatRad)
        );

        return [
            'latitude' => rad2deg($destLatRad),
            'longitude' => fmod(rad2deg($destLngRad) + 540.0, 360.0) - 180.0,
        ];
    }

    /**
     * Build a raw `ST_GeomFromText(...)` expression for use as an attribute value in a
     * create/update/insert — Eloquent embeds Expression values verbatim in the query.
     */
    public static function toPointExpression(float $latitude, float $longitude): Expression
    {
        return DB::raw(self::pointSql($latitude, $longitude));
    }

    private static function pointSql(float $latitude, float $longitude): string
    {
        self::assertValidCoordinates($latitude, $longitude);

        $wkt = sprintf(
            'POINT(%s %s)',
            self::formatCoordinate($longitude),
            self::formatCoordinate($latitude),
        );

        // MariaDB's ST_GeomFromText() has no `options` parameter and never reorders
        // axes for a given SRID in the first place, so plain (longitude, latitude) WKT
        // already round-trips correctly through ST_X()/ST_Y() as-is. Real MySQL 8 does
        // enforce the EPSG:4326 (latitude, longitude) axis order unless told otherwise,
        // so it needs the explicit override.
        return DB::connection()->isMaria()
            ? "ST_GeomFromText('{$wkt}', 4326)"
            : "ST_GeomFromText('{$wkt}', 4326, 'axis-order=long-lat')";
    }

    private static function formatCoordinate(float $value): string
    {
        // Locale-independent, fixed-notation formatting — guarantees the interpolated
        // value can only ever match /-?\d+\.\d+/, so it is safe to embed directly in
        // raw SQL without parameter binding.
        return number_format($value, 8, '.', '');
    }

    private static function assertValidCoordinates(float $latitude, float $longitude): void
    {
        if (! is_finite($latitude) || $latitude < -90.0 || $latitude > 90.0) {
            throw new InvalidArgumentException("Invalid latitude [{$latitude}]: must be finite and between -90 and 90.");
        }

        if (! is_finite($longitude) || $longitude < -180.0 || $longitude > 180.0) {
            throw new InvalidArgumentException("Invalid longitude [{$longitude}]: must be finite and between -180 and 180.");
        }
    }

    /**
     * Fetch the decoded fuzzy coordinates for this record with a lightweight query.
     * For fetching coordinates on many records at once, use scopeSelectFuzzyCoordinates
     * instead to avoid N+1 queries.
     *
     * @return array{latitude: float, longitude: float}|null
     */
    public function getFuzzyCoordinates(): ?array
    {
        return $this->decodedPointCoordinates('fuzzy_location');
    }

    /**
     * Fetch the decoded exact coordinates for this record. Server-side use only
     * (background jobs, refreshFuzzyLocation, admin tooling) — never return this from
     * an API response.
     *
     * @return array{latitude: float, longitude: float}|null
     */
    public function getExactCoordinates(): ?array
    {
        return $this->decodedPointCoordinates('base_location');
    }

    /**
     * @return array{latitude: float, longitude: float}|null
     */
    private function decodedPointCoordinates(string $column): ?array
    {
        $row = static::query()
            ->whereKey($this->getKey())
            ->selectRaw("ST_Y({$column}) as latitude, ST_X({$column}) as longitude")
            ->first();

        if (! $row || $row->latitude === null || $row->longitude === null) {
            return null;
        }

        return ['latitude' => (float) $row->latitude, 'longitude' => (float) $row->longitude];
    }

    /**
     * Add decoded `{column}_latitude` / `{column}_longitude` columns to the select
     * list, e.g. for map pins on an index endpoint without an N+1 query per row.
     */
    public function scopeSelectFuzzyCoordinates(Builder $query, string $column = 'fuzzy_location'): Builder
    {
        self::ensureWildcardSelect($query);

        return $query->addSelect([
            DB::raw("ST_Y({$column}) as {$column}_latitude"),
            DB::raw("ST_X({$column}) as {$column}_longitude"),
        ]);
    }

    /**
     * Once any explicit select/addSelect/selectRaw is applied to a query, Eloquent
     * stops implicitly adding `*`, silently dropping every normal model column. Both
     * scopes below add raw computed columns, so they must opt back into `*` first.
     */
    private static function ensureWildcardSelect(Builder $query): void
    {
        if (is_null($query->getQuery()->columns)) {
            $query->select('*');
        }
    }

    /**
     * Filter to records whose $column lies within $radiusMeters of the given point,
     * ordered nearest-first, with the computed distance exposed as `distance_meters`.
     *
     * Uses ST_Distance_Sphere, which is precise enough for local/neighborhood-scale
     * radii and does not require a true geodesic (ellipsoidal) calculation.
     */
    public function scopeNearby(
        Builder $query,
        float $latitude,
        float $longitude,
        float $radiusMeters,
        string $column = 'fuzzy_location'
    ): Builder {
        self::assertValidCoordinates($latitude, $longitude);

        self::ensureWildcardSelect($query);
        $originSql = self::pointSql($latitude, $longitude);

        return $query
            ->whereNotNull($column)
            ->addSelect(DB::raw("ST_Distance_Sphere({$column}, {$originSql}) as distance_meters"))
            ->havingRaw('distance_meters <= ?', [$radiusMeters])
            ->orderBy('distance_meters');
    }
}
