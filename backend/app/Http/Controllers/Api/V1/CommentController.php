<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\NotificationType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Comment\StoreCommentRequest;
use App\Http\Resources\CommentResource;
use App\Models\Comment;
use App\Models\Post;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class CommentController extends Controller
{
    private const PER_PAGE = 30;

    public function index(Request $request, Post $post): AnonymousResourceCollection
    {
        $this->authorize('view', $post);

        $comments = $post->comments()
            ->whereNotIn('author_id', $request->user()->hiddenUserIds())
            ->with(['author', 'replyingToUser'])
            ->oldest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return CommentResource::collection($comments);
    }

    public function store(StoreCommentRequest $request, Post $post, NotificationService $notificationService): JsonResponse
    {
        $this->authorize('view', $post);

        $data = $request->validated();

        $comment = new Comment(['body' => $data['body']]);
        $comment->author_id = $request->user()->id;

        $repliedTo = null;

        if (! empty($data['reply_to_comment_id'])) {
            $repliedTo = $post->comments()->find($data['reply_to_comment_id']);

            if ($repliedTo === null) {
                throw ValidationException::withMessages([
                    'reply_to_comment_id' => ['That comment could not be found on this post.'],
                ]);
            }

            // Flatten reply-to-a-reply into the same top-level thread —
            // parent_id always points at the top-level comment.
            $comment->parent_id = $repliedTo->parent_id ?? $repliedTo->id;
            $comment->replying_to_user_id = $repliedTo->author_id;
        }

        $post->comments()->save($comment);
        $post->loadMissing('author');

        $notificationService->notify(
            $post->author,
            $request->user(),
            NotificationType::PostCommented,
            "{$request->user()->name} commented on your post",
            Str::limit($comment->body, 100),
            ['post_id' => $post->id, 'comment_id' => $comment->id],
        );

        // A reply also notifies the specific comment's author it's addressing
        // — not necessarily the post's author, and not necessarily the
        // top-level comment's author if replying to a reply (see the
        // parent_id-flattening comment above). Two guards keep this from
        // ever producing a duplicate of the PostCommented notification just
        // sent above, or a self-notification: skip if the replier is
        // replying to their own comment, and skip if the parent comment's
        // author IS the post's author (who already got notified above).
        if ($repliedTo !== null
            && $comment->replying_to_user_id !== $request->user()->id
            && $comment->replying_to_user_id !== $post->author_id
        ) {
            $notificationService->notify(
                $repliedTo->author,
                $request->user(),
                NotificationType::CommentReplied,
                "{$request->user()->name} replied to your comment",
                Str::limit($comment->body, 100),
                ['post_id' => $post->id, 'comment_id' => $comment->id, 'parent_id' => $comment->parent_id],
            );
        }

        return (new CommentResource($comment->fresh(['author', 'replyingToUser'])))
            ->response()
            ->setStatusCode(201);
    }

    public function destroy(Comment $comment): JsonResponse
    {
        $this->authorize('delete', $comment);

        $comment->delete();

        return response()->json(['message' => 'Comment deleted.']);
    }
}
