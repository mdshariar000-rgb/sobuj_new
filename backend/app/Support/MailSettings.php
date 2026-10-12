<?php

namespace App\Support;

use App\Models\Setting;
use Throwable;

/**
 * SMTP settings saved on the admin Settings page, laid over config/mail.php
 * (the .env values) whenever mail is about to be sent — see
 * AppServiceProvider. Nothing changes until a host is saved, so a fresh
 * install keeps using .env.
 */
final class MailSettings
{
    public const KEYS = [
        'mail_host',
        'mail_port',
        'mail_encryption',
        'mail_username',
        'mail_password',
        'mail_from_address',
        'mail_from_name',
    ];

    /** @return array<string, ?string> */
    public static function saved(): array
    {
        try {
            // One query for all of them; the model decrypts each value.
            $rows = Setting::query()->whereIn('key', self::KEYS)->get()->pluck('value', 'key');
        } catch (Throwable) {
            // No database yet (fresh install, package discovery): use .env.
            return [];
        }

        return collect(self::KEYS)->mapWithKeys(fn ($key) => [$key => $rows[$key] ?? null])->all();
    }

    public static function apply(): void
    {
        $saved = self::saved();
        if (blank($saved['mail_host'] ?? null)) {
            return;
        }

        config([
            'mail.default' => 'smtp',
            'mail.mailers.smtp.url' => null,
            'mail.mailers.smtp.host' => $saved['mail_host'],
            'mail.mailers.smtp.port' => (int) ($saved['mail_port'] ?: 587),
            // 465 is SSL from the first byte ("smtps"); 587 upgrades with STARTTLS.
            'mail.mailers.smtp.scheme' => ($saved['mail_encryption'] ?? null) === 'ssl' ? 'smtps' : 'smtp',
            'mail.mailers.smtp.username' => $saved['mail_username'],
            'mail.mailers.smtp.password' => $saved['mail_password'],
        ]);

        if (filled($saved['mail_from_address'] ?? null)) {
            config(['mail.from.address' => $saved['mail_from_address']]);
        }
        if (filled($saved['mail_from_name'] ?? null)) {
            config(['mail.from.name' => $saved['mail_from_name']]);
        }
    }
}
