<?php

namespace App\Filament\Resources;

use App\Enums\GroupMemberRole;
use App\Enums\GroupVisibility;
use App\Filament\Resources\GroupRequestResource\Pages;
use App\Models\Group;
use App\Models\GroupRequest;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Users' requests for new groups (POST /api/v1/group-requests). Approving
 * creates the group as a public group with the requester as its admin.
 */
class GroupRequestResource extends Resource
{
    protected static ?string $model = GroupRequest::class;

    protected static ?string $navigationIcon = 'heroicon-o-user-group';

    protected static ?string $navigationGroup = 'Moderation';

    protected static ?string $navigationLabel = 'Group Requests';

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getNavigationBadge(): ?string
    {
        $pending = GroupRequest::where('status', GroupRequest::STATUS_PENDING)->count();

        return $pending > 0 ? (string) $pending : null;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->searchable()->weight('bold'),
                TextColumn::make('description')->limit(80)->wrap(),
                TextColumn::make('user.name')->label('Requested by')->searchable(),
                TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state) => match ($state) {
                        GroupRequest::STATUS_APPROVED => 'success',
                        GroupRequest::STATUS_DECLINED => 'gray',
                        default => 'warning',
                    }),
                TextColumn::make('created_at')->label('Requested')->since()->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        GroupRequest::STATUS_PENDING => 'Pending',
                        GroupRequest::STATUS_APPROVED => 'Approved',
                        GroupRequest::STATUS_DECLINED => 'Declined',
                    ])
                    ->default(GroupRequest::STATUS_PENDING),
            ])
            ->actions([
                Action::make('approve')
                    ->label('Approve & create group')
                    ->icon('heroicon-o-check')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (GroupRequest $record) => $record->status === GroupRequest::STATUS_PENDING)
                    ->action(function (GroupRequest $record) {
                        self::approve($record);
                        Notification::make()->title("Created \"{$record->name}\"")->success()->send();
                    }),
                Action::make('decline')
                    ->icon('heroicon-o-x-mark')
                    ->color('gray')
                    ->requiresConfirmation()
                    ->visible(fn (GroupRequest $record) => $record->status === GroupRequest::STATUS_PENDING)
                    ->action(fn (GroupRequest $record) => $record->forceFill([
                        'status' => GroupRequest::STATUS_DECLINED,
                    ])->save()),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function approve(GroupRequest $record): Group
    {
        return DB::transaction(function () use ($record): Group {
            $base = Str::slug($record->name) ?: 'group';
            $slug = $base;
            for ($i = 2; Group::where('slug', $slug)->exists(); $i++) {
                $slug = "{$base}-{$i}";
            }

            $group = new Group([
                'name' => $record->name,
                'slug' => $slug,
                'description' => $record->description,
                'visibility' => GroupVisibility::Public,
            ]);
            $group->created_by = $record->user_id;
            $group->save();

            $group->members()->attach($record->user_id, [
                'role' => GroupMemberRole::Admin,
                'joined_at' => now(),
                'last_read_message_id' => 0,
            ]);

            $record->forceFill(['status' => GroupRequest::STATUS_APPROVED])->save();

            return $group;
        });
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGroupRequests::route('/'),
        ];
    }
}
