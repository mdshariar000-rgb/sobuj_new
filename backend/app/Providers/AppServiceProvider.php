<?php

namespace App\Providers;

use App\Services\Push\FcmPushSender;
use App\Services\Push\PushSender;
use App\Support\MailSettings;
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

        // Tests bind a fake PushSender instead — see NotificationService,
        // never send a real push in the automated suite.
        $this->app->bind(PushSender::class, FcmPushSender::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // SMTP saved on the admin Settings page beats .env. Applied when the
        // mailer is first needed, so requests that send no mail don't pay
        // for the lookup.
        $this->app->afterResolving('mail.manager', fn () => MailSettings::apply());
    }
}
