<?php

namespace App\Services;

use App\Exceptions\ImageProcessingException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Intervention\Image\Exceptions\DecoderException;
use Intervention\Image\ImageManager;

/**
 * Decodes, normalizes, and re-encodes user-uploaded photos before they ever touch
 * storage.
 *
 * The re-encode is what actually strips EXIF (including GPS geotags): decoding into
 * Intervention's internal representation and writing back out via the GD driver
 * produces a brand new JPEG byte stream that never carries the original file's
 * metadata — GD's encoder has no code path capable of writing EXIF/APP1 segments at
 * all, so this is true regardless of the `strip` flag passed to toJpeg(). The flag is
 * still passed explicitly so the guarantee holds if the driver is ever swapped to
 * Imagick (which can otherwise carry metadata through by default).
 */
class ImageService
{
    private const MAX_DIMENSION_PX = 1600;

    private const JPEG_QUALITY = 82;

    public function __construct(private readonly ImageManager $manager) {}

    /**
     * Process an uploaded photo and store it under $directory on the given disk.
     *
     * @return string The stored file's path relative to the disk root.
     *
     * @throws ImageProcessingException if the file cannot be decoded as an image.
     */
    public function store(UploadedFile $file, string $directory, string $disk = 'public'): string
    {
        try {
            $image = $this->manager->read($file->getRealPath());
        } catch (DecoderException $e) {
            throw new ImageProcessingException(
                "Uploaded file [{$file->getClientOriginalName()}] could not be decoded as an image.",
                previous: $e,
            );
        }

        // Bakes the EXIF orientation tag into the actual pixels (so the photo still
        // displays right-side-up once the tag itself is gone) before anything is
        // encoded/stripped. Config::$autoOrientation already does this on read, but it
        // is called again explicitly here so the behavior doesn't depend on that
        // global default remaining unchanged.
        $image->orient();

        // Downscales in place; never upscales a smaller image.
        $image->scaleDown(width: self::MAX_DIMENSION_PX, height: self::MAX_DIMENSION_PX);

        $encoded = $image->toJpeg(quality: self::JPEG_QUALITY, strip: true);

        $path = sprintf('%s/%s.jpg', trim($directory, '/'), (string) Str::uuid());

        Storage::disk($disk)->put($path, (string) $encoded);

        return $path;
    }

    public function delete(string $path, string $disk = 'public'): void
    {
        Storage::disk($disk)->delete($path);
    }
}
