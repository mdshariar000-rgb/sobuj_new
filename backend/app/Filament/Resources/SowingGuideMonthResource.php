<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SowingGuideMonthResource\Pages;
use App\Models\SowingGuideMonth;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\TagsInput;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;

/**
 * The 12-month UK sowing guide behind the mobile app's "What can you grow
 * now?" screen — see GET /api/v1/sowing-guide. Edit-only: the months are
 * fixed rows seeded by the migration, so there's no create or delete.
 */
class SowingGuideMonthResource extends Resource
{
    protected static ?string $model = SowingGuideMonth::class;

    protected static ?string $navigationIcon = 'heroicon-o-sun';

    protected static ?string $navigationGroup = 'Content';

    protected static ?string $navigationLabel = 'What Can You Grow';

    protected static ?string $modelLabel = 'sowing guide month';

    protected static ?int $navigationSort = 1;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Placeholder::make('month_name')
                ->label('Month')
                ->content(fn (?SowingGuideMonth $record) => $record?->monthName()),

            TagsInput::make('outdoors')
                ->label('Sow or plant outdoors')
                ->placeholder('Add a plant and press Enter')
                ->helperText('Shown in the app under "Sow or plant outdoors", in this order.')
                ->reorderable()
                ->nestedRecursiveRules(['string', 'max:100'])
                ->columnSpanFull(),

            TagsInput::make('under_cover')
                ->label('Start under cover')
                ->placeholder('Add a plant and press Enter')
                ->helperText('Greenhouse or windowsill — shown under "Start under cover".')
                ->reorderable()
                ->nestedRecursiveRules(['string', 'max:100'])
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('month')
                    ->formatStateUsing(fn (SowingGuideMonth $record) => $record->monthName())
                    ->sortable(),

                TextColumn::make('outdoors')
                    ->label('Outdoors')
                    ->badge()
                    ->limitList(4),

                TextColumn::make('under_cover')
                    ->label('Under cover')
                    ->badge()
                    ->limitList(4),

                TextColumn::make('updated_at')
                    ->label('Last edited')
                    ->since()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->actions([
                EditAction::make(),
            ])
            ->defaultSort('month')
            ->paginated(false);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSowingGuideMonths::route('/'),
            'edit' => Pages\EditSowingGuideMonth::route('/{record}/edit'),
        ];
    }
}
