<?php

namespace App\Filament\Resources;

use App\Filament\Resources\BannedSpeciesResource\Pages;
use App\Models\BannedSpecies;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables\Actions\BulkActionGroup;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

/**
 * Plain CRUD over the list of prohibited/invasive plant names checked by
 * App\Rules\NotBannedSpecies against listing titles/varieties.
 */
class BannedSpeciesResource extends Resource
{
    protected static ?string $model = BannedSpecies::class;

    protected static ?string $navigationIcon = 'heroicon-o-shield-exclamation';

    protected static ?string $navigationGroup = 'Moderation';

    protected static ?string $navigationLabel = 'Banned Species';

    protected static ?int $navigationSort = 6;

    public static function form(Form $form): Form
    {
        return $form->schema([
            TextInput::make('name')
                ->label('Species name')
                ->required()
                ->maxLength(255)
                ->unique(ignoreRecord: true)
                ->helperText('Matched case-insensitively as a substring of listing titles/varieties.'),

            Textarea::make('notes')
                ->label('Notes')
                ->maxLength(1000)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('notes')
                    ->limit(60)
                    ->toggleable(),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->actions([
                EditAction::make(),
                DeleteAction::make(),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('name');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListBannedSpecies::route('/'),
            'create' => Pages\CreateBannedSpecies::route('/create'),
            'edit' => Pages\EditBannedSpecies::route('/{record}/edit'),
        ];
    }
}
