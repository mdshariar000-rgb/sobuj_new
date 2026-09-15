<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Comment\StoreCommentRequest;
use App\Http\Resources\CommentResource;
use App\Models\Comment;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

class CommentController extends Controller
{
    private const PER_PAGE = 30;

    public function index(Post $post): AnonymousResourceCollection
    {
        $this->authorize('view', $post);

        $comments = $post->comments()
            ->with(['author', 'replyingToUser'])
            ->oldest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return CommentResource::collection($comments);
    }

    public function store(StoreCommentRequest $request, Post $post): JsonResponse
    {
        $this->authorize('view', $post);

        $data = $request->validated();

        $comment = new Comment(['body' => $data['body']]);
        $comment->author_id = $request->user()->id;

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
