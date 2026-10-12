<?php

namespace App\Filament\Pages;

use App\Models\Setting;
use App\Services\PostcodeAddressService;
use App\Support\MailSettings;
use App\Support\SocialSettings;
use Filament\Actions\Action;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Grid;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * A single settings screen (not a Resource — there's only ever one "row" of
 * config to edit) for values that need to be changeable without SSH/.env
 * access: the Firebase push credentials and the public support email. Add
 * more fields here as more admin-editable settings are needed —
 * Setting::get()/set() already support any string key.
 */
class ManageSettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationGroup = 'System';

    protected static ?string $navigationLabel = 'Settings';

    protected static ?int $navigationSort = 1;

    protected static ?string $title = 'Settings';

    protected static string $view = 'filament.pages.manage-settings';

    /**
     * Relative to the 'local' disk (storage/app/private — never web-
     * accessible), which is exactly what config/firebase.php's default
     * `credentials` path points at. Kreait reads this file fresh off disk
     * each time it builds the Messaging client, so overwriting it here takes
     * effect immediately — no redeploy or config:cache needed.
     */
    private const FIREBASE_CREDENTIALS_PATH = 'firebase-service-account.json';

    /**
     * The exact keys a real Firebase service-account JSON always has — used
     * to reject an upload that isn't one before it ever overwrites a
     * working credentials file.
     *
     * @var list<string>
     */
    private const FIREBASE_CREDENTIALS_REQUIRED_KEYS = [
        'type', 'project_id', 'private_key', 'client_email',
    ];

    /**
     * @var array<string, mixed>
     */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill($this->savedState());
    }

    /**
     * Everything the form shows. Secrets (API key, SMTP password) are never
     * sent back to the browser — a blank field keeps what's saved.
     *
     * @return array<string, mixed>
     */
    private function savedState(): array
    {
        $mail = MailSettings::saved();

        return [
            'support_email' => (string) Setting::get('support_email', ''),
            'app_store_url' => (string) Setting::get('app_store_url', ''),
            'android_download_url' => (string) Setting::get('android_download_url', ''),
            'ideal_postcodes_api_key' => null,
            'firebase_credentials' => null,
            ...$this->socialState(),
            'mail_host' => (string) ($mail['mail_host'] ?? ''),
            'mail_port' => (string) ($mail['mail_port'] ?? ''),
            'mail_encryption' => $mail['mail_encryption'] ?? 'tls',
            'mail_username' => (string) ($mail['mail_username'] ?? ''),
            'mail_password' => null,
            'mail_from_address' => (string) ($mail['mail_from_address'] ?? ''),
            'mail_from_name' => (string) ($mail['mail_from_name'] ?? ''),
        ];
    }

    /** @return array<string, mixed> */
    private function socialState(): array
    {
        $s = SocialSettings::all();

        return [
            SocialSettings::GOOGLE_ENABLED => ($s[SocialSettings::GOOGLE_ENABLED] ?? null) === '1',
            SocialSettings::GOOGLE_IOS_CLIENT_ID => (string) ($s[SocialSettings::GOOGLE_IOS_CLIENT_ID] ?? ''),
            SocialSettings::GOOGLE_SERVER_CLIENT_ID => (string) ($s[SocialSettings::GOOGLE_SERVER_CLIENT_ID] ?? ''),
            SocialSettings::GOOGLE_EXTRA_CLIENT_IDS => (string) ($s[SocialSettings::GOOGLE_EXTRA_CLIENT_IDS] ?? ''),
            SocialSettings::APPLE_ENABLED => ($s[SocialSettings::APPLE_ENABLED] ?? null) === '1',
            SocialSettings::APPLE_CLIENT_ID => (string) ($s[SocialSettings::APPLE_CLIENT_ID] ?? ''),
            SocialSettings::APPLE_TEAM_ID => (string) ($s[SocialSettings::APPLE_TEAM_ID] ?? ''),
            SocialSettings::APPLE_KEY_ID => (string) ($s[SocialSettings::APPLE_KEY_ID] ?? ''),
            SocialSettings::APPLE_PRIVATE_KEY => null,
        ];
    }

    protected function getHeaderActions(): array
    {
        return [
            Action::make('sendTestEmail')
                ->label('Send test email')
                ->icon('heroicon-o-envelope')
                ->color('gray')
                ->modalDescription('Sends a short email using the saved settings. Save any changes first.')
                ->form([
                    TextInput::make('to')
                        ->label('Send to')
                        ->email()
                        ->required()
                        ->default(fn () => auth()->user()?->email),
                ])
                ->action(fn (array $data) => $this->sendTestEmail($data['to'])),
        ];
    }

    public function sendTestEmail(string $to): void
    {
        MailSettings::apply();
        app('mail.manager')->purge('smtp');

        try {
            Mail::raw(
                'This is a test from the '.config('mail.from.name').' admin panel. If you can read it, email is working.',
                fn ($message) => $message->to($to)->subject('Test email from '.config('mail.from.name')),
            );
        } catch (Throwable $e) {
            Notification::make()
                ->title('The test email could not be sent')
                ->body($e->getMessage())
                ->danger()
                ->persistent()
                ->send();

            return;
        }

        Notification::make()
            ->title("Test email sent to {$to}")
            ->body('Check that inbox (and its spam folder).')
            ->success()
            ->send();
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('Push Notifications (Firebase)')
                    ->description('Powers like/comment/message push notifications. Upload the service-account JSON downloaded from Firebase Console → Project Settings → Service Accounts → Generate new private key.')
                    ->schema([
                        Placeholder::make('firebase_credentials_status')
                            ->label('Current status')
                            ->content($this->firebaseCredentialsStatus()),
                        FileUpload::make('firebase_credentials')
                            ->label('Service Account JSON')
                            ->disk('local')
                            ->directory('firebase-uploads-tmp')
                            ->acceptedFileTypes(['application/json', 'text/plain'])
                            ->maxSize(1024)
                            ->helperText('Leave blank to keep the current credentials unchanged.'),
                    ]),
                Section::make('Support Contact')
                    ->description('Shown on the public Privacy Policy and Terms pages (codecell.site/privacy, /terms). The App Store requires a working contact address.')
                    ->schema([
                        TextInput::make('support_email')
                            ->label('Support email')
                            ->email()
                            ->maxLength(255),
                    ]),
                Section::make('Address Lookup (Ideal Postcodes)')
                    ->description('Sign-up and "Your address": the user types a postcode and picks their address from Royal Mail\'s list. Paid per lookup — create an account and buy credits at ideal-postcodes.co.uk, then paste the API key (starts with ak_) here. Without a key, the app fills in the town and asks for the street.')
                    ->schema([
                        Placeholder::make('ideal_postcodes_status')
                            ->label('Current status')
                            ->content(fn () => app(PostcodeAddressService::class)->isConfigured()
                                ? '✅ Configured — addresses fill in from the postcode.'
                                : '❌ Not configured — users type their house and street.'),
                        TextInput::make('ideal_postcodes_api_key')
                            ->label('API key')
                            ->password()
                            ->revealable()
                            ->maxLength(255)
                            ->helperText('Leave blank to keep the current key unchanged.'),
                    ]),
                Section::make('Social Sign-in: Google')
                    ->description('From Google Cloud Console → APIs & Services → Credentials (Firebase project). The app reads these from the server, so changes apply without a new app build — except on iPhone, where the iOS client\'s reversed id must also be in the app\'s Info.plist (a one-time app update).')
                    ->schema([
                        Placeholder::make('google_status')
                            ->label('Current status')
                            ->content(fn () => SocialSettings::googleEnabled(SocialSettings::all())
                                ? '✅ "Continue with Google" is on.'
                                : '❌ Off — switch it on and add the client IDs.'),
                        Toggle::make(SocialSettings::GOOGLE_ENABLED)
                            ->label('Allow "Continue with Google"'),
                        TextInput::make(SocialSettings::GOOGLE_IOS_CLIENT_ID)
                            ->label('iOS client ID')
                            ->placeholder('1234-ios.apps.googleusercontent.com')
                            ->maxLength(255),
                        TextInput::make(SocialSettings::GOOGLE_SERVER_CLIENT_ID)
                            ->label('Web client ID (used by Android)')
                            ->placeholder('1234-web.apps.googleusercontent.com')
                            ->helperText('Android also needs its own Android client (package com.greensheal.shobuj + signing SHA-1) to exist in the same project — nothing to paste here for it.')
                            ->maxLength(255),
                        Textarea::make(SocialSettings::GOOGLE_EXTRA_CLIENT_IDS)
                            ->label('Other accepted client IDs (optional)')
                            ->rows(2)
                            ->helperText('One per line — only if another app or website also signs in to these accounts.'),
                    ]),
                Section::make('Social Sign-in: Apple')
                    ->description('Sign in with Apple must also be enabled for the App ID in the Apple Developer account (Certificates, Identifiers & Profiles), and the App Store profile regenerated.')
                    ->schema([
                        Placeholder::make('apple_status')
                            ->label('Current status')
                            ->content(function () {
                                $settings = SocialSettings::all();
                                if (! SocialSettings::appleEnabled($settings)) {
                                    return '❌ Off.';
                                }

                                return SocialSettings::appleKeyConfigured($settings)
                                    ? '✅ "Continue with Apple" is on, and deleted accounts are unlinked from Apple.'
                                    : '⚠️ "Continue with Apple" is on, but add the key below — Apple requires unlinking when an account is deleted.';
                            }),
                        Toggle::make(SocialSettings::APPLE_ENABLED)
                            ->label('Allow "Continue with Apple" (iPhone)'),
                        TextInput::make(SocialSettings::APPLE_CLIENT_ID)
                            ->label('App bundle ID / Services ID')
                            ->placeholder('com.greenshelter.shobuj')
                            ->maxLength(255),
                        Grid::make(2)->schema([
                            TextInput::make(SocialSettings::APPLE_TEAM_ID)
                                ->label('Team ID')
                                ->placeholder('XCGZVG9PT7')
                                ->maxLength(20),
                            TextInput::make(SocialSettings::APPLE_KEY_ID)
                                ->label('Key ID')
                                ->placeholder('ABC123DEFG')
                                ->maxLength(20),
                        ]),
                        Textarea::make(SocialSettings::APPLE_PRIVATE_KEY)
                            ->label('Private key (.p8 file contents)')
                            ->rows(4)
                            ->placeholder("-----BEGIN PRIVATE KEY-----\n…\n-----END PRIVATE KEY-----")
                            ->helperText('Keys → create a key with "Sign in with Apple" enabled. Leave blank to keep the current key. Never shown again after saving.')
                            ->rule(fn () => function (string $attribute, $value, \Closure $fail) {
                                if (filled($value) && openssl_pkey_get_private((string) $value) === false) {
                                    $fail('That isn\'t a valid .p8 private key — paste the whole file, including the BEGIN/END lines.');
                                }
                            }),
                    ]),
                Section::make('Email (SMTP)')
                    ->description('Sends password-reset codes and other emails. Leave the host blank to keep using the server\'s .env settings. For Gmail: host smtp.gmail.com, port 587, STARTTLS, your Gmail address, and an App Password (not the account password).')
                    ->schema([
                        Placeholder::make('mail_status')
                            ->label('Current status')
                            ->content(fn () => filled(MailSettings::saved()['mail_host'] ?? null)
                                ? '✅ Using the settings below.'
                                : 'Using the server\'s .env settings ('.(config('mail.mailers.smtp.host') ?: 'none').').'),
                        Grid::make(3)->schema([
                            TextInput::make('mail_host')
                                ->label('SMTP host')
                                ->placeholder('smtp.gmail.com')
                                ->maxLength(255)
                                ->columnSpan(2),
                            TextInput::make('mail_port')
                                ->label('Port')
                                ->numeric()
                                ->placeholder('587')
                                ->requiredWith('mail_host'),
                        ]),
                        Select::make('mail_encryption')
                            ->label('Security')
                            ->options([
                                'tls' => 'STARTTLS (usually port 587)',
                                'ssl' => 'SSL (usually port 465)',
                            ])
                            ->selectablePlaceholder(false),
                        TextInput::make('mail_username')
                            ->label('Username')
                            ->maxLength(255)
                            ->requiredWith('mail_host'),
                        TextInput::make('mail_password')
                            ->label('Password')
                            ->password()
                            ->revealable()
                            ->maxLength(255)
                            ->helperText('Leave blank to keep the current password unchanged.'),
                        TextInput::make('mail_from_address')
                            ->label('From address')
                            ->email()
                            ->maxLength(255)
                            ->requiredWith('mail_host'),
                        TextInput::make('mail_from_name')
                            ->label('From name')
                            ->placeholder('Shobuj')
                            ->maxLength(100),
                    ]),
                Section::make('App Download Links')
                    ->description('Buttons on the pages opened from the app\'s Share links (codecell.site/l/…, /u/…). Leave one blank to hide its button.')
                    ->schema([
                        TextInput::make('app_store_url')
                            ->label('iPhone (App Store) link')
                            ->url()
                            ->maxLength(500),
                        TextInput::make('android_download_url')
                            ->label('Android link (Play Store or APK)')
                            ->url()
                            ->maxLength(500),
                    ]),
            ])
            ->statePath('data');
    }

    private function firebaseCredentialsStatus(): string
    {
        if (! Storage::disk('local')->exists(self::FIREBASE_CREDENTIALS_PATH)) {
            return '❌ Not configured — push notifications will silently fail to send until a credentials file is uploaded.';
        }

        $uploadedAt = Storage::disk('local')->lastModified(self::FIREBASE_CREDENTIALS_PATH);

        return '✅ Configured — uploaded '.Carbon::createFromTimestamp($uploadedAt)->diffForHumans();
    }

    public function save(): void
    {
        $state = $this->form->getState();

        if (filled($state['firebase_credentials'] ?? null) && ! $this->saveFirebaseCredentials($state['firebase_credentials'])) {
            return;
        }

        $postcodeKey = trim((string) ($state['ideal_postcodes_api_key'] ?? ''));
        if ($postcodeKey !== '') {
            Setting::set(PostcodeAddressService::SETTING_KEY, $postcodeKey);
        }

        $plain = [
            'support_email', 'app_store_url', 'android_download_url',
            SocialSettings::GOOGLE_IOS_CLIENT_ID, SocialSettings::GOOGLE_SERVER_CLIENT_ID, SocialSettings::GOOGLE_EXTRA_CLIENT_IDS,
            SocialSettings::APPLE_CLIENT_ID, SocialSettings::APPLE_TEAM_ID, SocialSettings::APPLE_KEY_ID,
            'mail_host', 'mail_port', 'mail_encryption', 'mail_username', 'mail_from_address', 'mail_from_name',
        ];
        foreach ($plain as $key) {
            $value = trim((string) ($state[$key] ?? ''));
            Setting::set($key, $value !== '' ? $value : null);
        }

        foreach ([SocialSettings::GOOGLE_ENABLED, SocialSettings::APPLE_ENABLED] as $key) {
            Setting::set($key, ($state[$key] ?? false) ? '1' : '0');
        }

        $appleKey = trim((string) ($state[SocialSettings::APPLE_PRIVATE_KEY] ?? ''));
        if ($appleKey !== '') {
            Setting::set(SocialSettings::APPLE_PRIVATE_KEY, $appleKey);
        }

        $mailPassword = (string) ($state['mail_password'] ?? '');
        if ($mailPassword !== '') {
            Setting::set('mail_password', $mailPassword);
        }

        // fill() replaces the whole form state — include every field kept.
        $this->form->fill($this->savedState());

        Notification::make()
            ->title('Settings saved')
            ->success()
            ->send();
    }

    /**
     * Validates the uploaded file actually looks like a Firebase
     * service-account JSON before it ever overwrites a working credentials
     * file, then moves it from Filament's temp upload location to the fixed
     * path config/firebase.php reads from. Returns false (having already
     * shown the error notification and cleaned up the temp file) when the
     * upload is rejected, so save() can leave every other setting untouched.
     */
    private function saveFirebaseCredentials(string $tmpPath): bool
    {
        $contents = Storage::disk('local')->get($tmpPath);
        $decoded = json_decode((string) $contents, true);

        $isValid = json_last_error() === JSON_ERROR_NONE
            && is_array($decoded)
            && ($decoded['type'] ?? null) === 'service_account'
            && collect(self::FIREBASE_CREDENTIALS_REQUIRED_KEYS)->every(fn (string $key) => filled($decoded[$key] ?? null));

        if (! $isValid) {
            Storage::disk('local')->delete($tmpPath);

            Notification::make()
                ->title('That doesn\'t look like a Firebase service-account JSON file')
                ->body('Download it fresh from Firebase Console → Project Settings → Service Accounts → Generate new private key, then try again. The previous credentials (if any) were left unchanged.')
                ->danger()
                ->send();

            return false;
        }

        Storage::disk('local')->put(self::FIREBASE_CREDENTIALS_PATH, $contents);
        Storage::disk('local')->delete($tmpPath);

        return true;
    }
}
