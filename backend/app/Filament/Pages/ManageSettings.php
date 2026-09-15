<?php

namespace App\Filament\Pages;

use App\Models\Setting;
use App\Services\StripePriceService;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;

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
        // Secrets never get prefilled — an admin who opens this page shouldn't
        // see them rendered on screen. Prices do get prefilled — not
        // sensitive, and re-typing the current price every save would be
        // needless friction (and risk an accidental repeat price change).
        $this->form->fill([
            ...array_fill_keys(self::SECRET_KEYS, ''),
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
                            ->helperText('Used by the Agri-AI Assistant. Leave blank to keep the current key unchanged.'),
                    ]),
                Section::make('Payment Gateway (Stripe)')
                    ->description('Powers the Agri-AI Premium subscription. Use test-mode keys until you\'re ready to accept real payments.')
                    ->schema([
                        $this->secretInput('stripe_publishable_key', 'Stripe Publishable Key'),
                        $this->secretInput('stripe_secret_key', 'Stripe Secret Key'),
                        $this->secretInput('stripe_webhook_secret', 'Stripe Webhook Signing Secret')
                            ->helperText('From the webhook endpoint configured in the Stripe Dashboard for this app\'s /stripe/webhook URL.'),
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

    private function secretInput(string $key, string $label): TextInput
    {
        $currentValueIsSet = filled(Setting::get($key));

        return TextInput::make($key)
            ->label($label)
            ->password()
            ->revealable()
            ->placeholder($currentValueIsSet ? 'Key is set — leave blank to keep it' : 'Not set');
    }

    public function save(StripePriceService $stripePriceService): void
    {
        $state = $this->form->getState();

        foreach (self::SECRET_KEYS as $key) {
            $value = trim((string) ($state[$key] ?? ''));

            if ($value !== '') {
                Setting::set($key, $value);
            }
        }

        $this->savePriceIfChanged($stripePriceService, 'stripe_monthly_price_usd', 'stripe_price_id_monthly', 'month', (float) $state['stripe_monthly_price_usd']);
        $this->savePriceIfChanged($stripePriceService, 'stripe_annual_price_usd', 'stripe_price_id_annual', 'year', (float) $state['stripe_annual_price_usd']);

        $this->form->fill(array_fill_keys(self::SECRET_KEYS, ''));

        Notification::make()
            ->title('Settings saved')
            ->success()
            ->send();
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
