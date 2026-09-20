<?php

namespace App\Filament\Pages;

use App\Models\Setting;
use App\Services\StripePriceService;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;

/**
 * A single settings screen (not a Resource — there's only ever one "row" of
 * config to edit) for values that need to be changeable without SSH/.env
 * access: the Gemini API key, the Stripe payment-gateway credentials, and
 * the Agri-AI Premium plan prices. Add more TextInputs here as more
 * admin-editable settings are needed — Setting::get()/set() already support
 * any string key.
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
     * Secret fields — never prefilled back into the form and only written to
     * the database when the admin actually types a new value.
     *
     * @var list<string>
     */
    private const SECRET_KEYS = [
        'gemini_api_key',
        'stripe_publishable_key',
        'stripe_secret_key',
        'stripe_webhook_secret',
    ];

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
     * Real dollar amounts — the only price the admin ever sees or edits.
     * The underlying Stripe Price ID (stripe_price_id_monthly/_annual) is
     * managed entirely by StripePriceService and never shown here.
     *
     * @var array<string, float>
     */
    private const DEFAULT_PRICES_USD = [
        'stripe_monthly_price_usd' => 9.99,
        'stripe_annual_price_usd' => 71.88,
    ];

    /**
     * @var array<string, mixed>
     */
    public ?array $data = [];

    public function mount(): void
    {
        // Secrets are prefilled so the admin can see what's currently stored
        // (masked by default; the field's reveal toggle shows it) — they're
        // gated behind the admin panel login, and being able to compare
        // against the value they're about to replace is worth more than
        // hiding it from an already-authenticated admin.
        $this->form->fill([
            ...$this->currentSecretValues(),
            'support_email' => (string) Setting::get('support_email', ''),
            ...array_combine(
                array_keys(self::DEFAULT_PRICES_USD),
                array_map(
                    fn (string $key, float $default) => (float) Setting::get($key, (string) $default),
                    array_keys(self::DEFAULT_PRICES_USD),
                    self::DEFAULT_PRICES_USD,
                ),
            ),
        ]);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('AI Assistant (Gemini)')
                    ->schema([
                        $this->secretInput('gemini_api_key', 'Gemini API Key')
                            ->helperText('Used by the Agri-AI Assistant. Click the eye icon to reveal the current key. Clearing the field and saving keeps the existing key.'),
                    ]),
                Section::make('Payment Gateway (Stripe)')
                    ->description('Powers the Agri-AI Premium subscription. Use test-mode keys until you\'re ready to accept real payments.')
                    ->schema([
                        $this->secretInput('stripe_publishable_key', 'Stripe Publishable Key'),
                        $this->secretInput('stripe_secret_key', 'Stripe Secret Key'),
                        $this->secretInput('stripe_webhook_secret', 'Stripe Webhook Signing Secret')
                            ->helperText('From the webhook endpoint configured in the Stripe Dashboard for this app\'s /stripe/webhook URL.'),
                    ]),
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
                Section::make('Agri-AI Premium Pricing')
                    ->description('Type the real price you want to charge — a new Stripe Price is created automatically behind the scenes. You never need to open Stripe yourself.')
                    ->schema([
                        TextInput::make('stripe_monthly_price_usd')
                            ->label('Monthly Plan Price')
                            ->numeric()
                            ->minValue(0.5)
                            ->prefix('$')
                            ->required(),
                        TextInput::make('stripe_annual_price_usd')
                            ->label('Annual Plan Price')
                            ->numeric()
                            ->minValue(0.5)
                            ->prefix('$')
                            ->required(),
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

    /**
     * @return array<string, string>
     */
    private function currentSecretValues(): array
    {
        return collect(self::SECRET_KEYS)
            ->mapWithKeys(fn (string $key) => [$key => (string) Setting::get($key, '')])
            ->all();
    }

    private function secretInput(string $key, string $label): TextInput
    {
        return TextInput::make($key)
            ->label($label)
            ->password()
            ->revealable()
            ->placeholder('Not set');
    }

    public function save(StripePriceService $stripePriceService): void
    {
        $state = $this->form->getState();

        if (filled($state['firebase_credentials'] ?? null) && ! $this->saveFirebaseCredentials($state['firebase_credentials'])) {
            return;
        }

        foreach (self::SECRET_KEYS as $key) {
            $value = trim((string) ($state[$key] ?? ''));

            if ($value !== '') {
                Setting::set($key, $value);
            }
        }

        $supportEmail = trim((string) ($state['support_email'] ?? ''));
        Setting::set('support_email', $supportEmail !== '' ? $supportEmail : null);

        $this->savePriceIfChanged($stripePriceService, 'stripe_monthly_price_usd', 'stripe_price_id_monthly', 'month', (float) $state['stripe_monthly_price_usd']);
        $this->savePriceIfChanged($stripePriceService, 'stripe_annual_price_usd', 'stripe_price_id_annual', 'year', (float) $state['stripe_annual_price_usd']);

        // fill() replaces the whole form state, not just the keys given —
        // the price fields have to be re-included here (with whatever was
        // just submitted) or they'd visibly blank out even though nothing
        // about them failed to save.
        $this->form->fill([
            ...$this->currentSecretValues(),
            'support_email' => (string) Setting::get('support_email', ''),
            'firebase_credentials' => null,
            'stripe_monthly_price_usd' => (float) $state['stripe_monthly_price_usd'],
            'stripe_annual_price_usd' => (float) $state['stripe_annual_price_usd'],
        ]);

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

    /**
     * Only calls the Stripe API (and only replaces the stored Price ID)
     * when the dollar amount actually changed — repointing to a new Stripe
     * Price on every save, even an unrelated one, would be wasteful and
     * would needlessly orphan Prices in the Stripe Dashboard.
     */
    private function savePriceIfChanged(
        StripePriceService $stripePriceService,
        string $amountSettingKey,
        string $priceIdSettingKey,
        string $interval,
        float $newAmount,
    ): void {
        $currentAmount = (float) Setting::get($amountSettingKey, (string) self::DEFAULT_PRICES_USD[$amountSettingKey]);

        if (abs($currentAmount - $newAmount) < 0.001) {
            return;
        }

        $priceId = $stripePriceService->updatePrice($interval, $newAmount);
        Setting::set($priceIdSettingKey, $priceId);
        Setting::set($amountSettingKey, (string) $newAmount);
    }
}
