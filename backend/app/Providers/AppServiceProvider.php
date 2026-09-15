<?php

namespace App\Providers;

use App\Models\Setting;
use Illuminate\Support\ServiceProvider;
use Intervention\Image\ImageManager;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // GD is used rather than Imagick: it's universally available without an extra
        // system dependency, and its JPEG encoder has no code path that can write EXIF
        // data back out, which makes the geotag-stripping guarantee in ImageService
        // structural rather than a matter of remembering to pass the right flag.
        $this->app->singleton(ImageManager::class, fn () => ImageManager::gd());
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // A key saved via the admin Settings page (app/Filament/Pages/ManageSettings.php)
        // always wins over .env — same reasoning as the Gemini key in AgriAssistantService,
        // but Cashier reads its own config directly (Cashier::stripe(), the Billable trait,
        // and its auto-registered /stripe/webhook route all pull from config('cashier.*')
        // rather than taking an injected client), so the overlay has to happen here instead
        // of at the call site. Cashier::stripe() re-reads config on every call rather than
        // caching a client for the process lifetime, so overlaying it once per request here
        // is sufficient — verified against vendor/laravel/cashier/src/Cashier.php.
        config([
            'cashier.key' => Setting::get('stripe_publishable_key') ?: config('cashier.key'),
            'cashier.secret' => Setting::get('stripe_secret_key') ?: config('cashier.secret'),
            'cashier.webhook.secret' => Setting::get('stripe_webhook_secret') ?: config('cashier.webhook.secret'),
        ]);
    }
}
