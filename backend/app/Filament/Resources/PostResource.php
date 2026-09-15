<?php

namespace App\Filament\Resources;

use App\Enums\PostModerationStatus;
use App\Filament\Resources\PostResource\Pages;
use App\Models\Post;
use App\Models\PostCategory;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Actions\ActionGroup;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

/**
 * Site-wide moderation over every post (Home Feed and group discussion
 * threads alike) — entirely separate from a group admin's own
 * approve/reject workflow (see Post::approval_status /
 * GroupDetailScreen's inline moderation). Posts are created by users
 * through the mobile app, not by admins.
 */
class PostResource extends Resource
{
    protected static ?string $model = Post::class;

    protected static ?string $navigationIcon = 'heroicon-o-document-text';

    protected static ?string $navigationLabel = 'Posts';

    protected static ?string $navigationGroup = 'Community';

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Textarea::make('body')
                ->required()
                ->maxLength(5000)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->withCount([
                'likedBy as likes_count',
                'comments',
            ]))
            ->columns([
                TextColumn::make('body')
                    ->limit(60)
                    ->searchable(),

                TextColumn::make('author.name')
                    ->label('Author')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('category')
                    ->badge(),

                TextColumn::make('group.name')
                    ->label('Group')
                    ->default('Home Feed')
                    ->sortable(),

                TextColumn::make('likes_count')
                    ->label('Likes')
                    ->numeric()
                    ->sortable(),

                TextColumn::make('comments_count')
                    ->label('Comments')
                    ->numeric()
                    ->sortable(),

                TextColumn::make('moderation_status')
                    ->badge()
                    ->color(fn (PostModerationStatus $state) => match ($state) {
                        PostModerationStatus::Visible => 'success',
                        PostModerationStatus::Deactivated => 'warning',
                        PostModerationStatus::Banned => 'danger',
                    })
                    ->formatStateUsing(fn (PostModerationStatus $state) => $state->label()),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('category')
                    ->options(fn () => PostCategory::query()->orderBy('name')->pluck('name', 'name')->all()),

                SelectFilter::make('moderation_status')
                    ->options(self::enumOptions(PostModerationStatus::cases())),
            ])
            ->actions([
                ActionGroup::make([
                    EditAction::make(),

                    Action::make('deactivate')
                        ->label('Deactivate')
                        ->icon('heroicon-o-eye-slash')
                        ->color('warning')
                        ->visible(fn (Post $record) => $record->moderation_status === PostModerationStatus::Visible)
                        ->requiresConfirmation()
                        ->modalDescription('Hides this post from every feed. Reversible via Reactivate.')
                        ->form([
                            Textarea::make('reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(fn (Post $record, array $data) => self::moderate(
                            $record,
                            PostModerationStatus::Deactivated,
                            $data['reason'],
                        )),

                    Action::make('reactivate')
                        ->label('Reactivate')
                        ->icon('heroicon-o-eye')
                        ->color('success')
                        ->visible(fn (Post $record) => $record->moderation_status === PostModerationStatus::Deactivated)
                        ->requiresConfirmation()
                        ->action(fn (Post $record) => self::moderate($record, PostModerationStatus::Visible, null)),

                    Action::make('ban')
                        ->label('Ban permanently')
                        ->icon('heroicon-o-no-symbol')
                        ->color('danger')
                        ->visible(fn (Post $record) => $record->moderation_status !== PostModerationStatus::Banned)
                        ->requiresConfirmation()
                        ->form([
                            Textarea::make('reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(fn (Post $record, array $data) => self::moderate(
                            $record,
                            PostModerationStatus::Banned,
                            $data['reason'],
                        )),

                    Action::make('restore')
                        ->label('Restore')
                        ->icon('heroicon-o-arrow-uturn-left')
                        ->color('success')
                        ->visible(fn (Post $record) => $record->moderation_status === PostModerationStatus::Banned)
                        ->requiresConfirmation()
                        ->action(fn (Post $record) => self::moderate($record, PostModerationStatus::Visible, null)),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    /**
     * moderation_status/moderation_reason/moderated_at/moderated_by aren't
     * mass-assignable (see Post::casts()) — set directly rather than via
     * update(), same reasoning as PostController::approve()/reject().
     */
    private static function moderate(Post $record, PostModerationStatus $status, ?string $reason): void
    {
        $record->moderation_status = $status;
        $record->moderation_reason = $reason;
        $record->moderated_at = $status === PostModerationStatus::Visible ? null : now();
        $record->moderated_by = $status === PostModerationStatus::Visible ? null : Auth::id();
        $record->save();
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPosts::route('/'),
            'edit' => Pages\EditPost::route('/{record}/edit'),
        ];
    }

    /**
     * @param  array<int, PostModerationStatus>  $cases
     * @return array<string, string>
     */
    private static function enumOptions(array $cases): array
    {
        return collect($cases)->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all();
    }
}
