<?php

namespace App\Filament\Resources;

use App\Filament\Resources\GroupCategoryResource\Pages;
use App\Models\GroupCategory;
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
 * Plain CRUD over the group categories the mobile app's "create a group"
 * screen picks from — see GET /api/v1/group-categories and
 * StoreGroupRequest/UpdateGroupRequest's validation against this list.
 */
class GroupCategoryResource extends Resource
{
    protected static ?string $model = GroupCategory::class;

    protected static ?string $navigationIcon = 'heroicon-o-tag';

    protected static ?string $navigationGroup = 'Community';

    protected static ?string $navigationLabel = 'Group Categories';

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
            'index' => Pages\ListGroupCategories::route('/'),
            'create' => Pages\CreateGroupCategory::route('/create'),
            'edit' => Pages\EditGroupCategory::route('/{record}/edit'),
        ];
    }
}
