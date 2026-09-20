<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ListingCategoryResource\Pages;
use App\Models\ListingCategory;
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
 * Plain CRUD over the marketplace listing categories the mobile app's
 * "create a listing" screen picks from — see GET /api/v1/listing-categories
 * and StoreListingRequest/UpdateListingRequest/NearbyListingsRequest's
 * validation against this list.
 */
class ListingCategoryResource extends Resource
{
    protected static ?string $model = ListingCategory::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-bag';

    protected static ?string $navigationGroup = 'Categories';

    protected static ?string $navigationLabel = 'Listing Categories';

    protected static ?int $navigationSort = 4;

    public static function form(Form $form): Form
    {
        return $form->schema([
            TextInput::make('name')
                ->label('Category name')
                ->required()
                ->maxLength(255)
                ->unique(ignoreRecord: true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),

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
            'index' => Pages\ListListingCategories::route('/'),
            'create' => Pages\CreateListingCategory::route('/create'),
            'edit' => Pages\EditListingCategory::route('/{record}/edit'),
        ];
    }
}
