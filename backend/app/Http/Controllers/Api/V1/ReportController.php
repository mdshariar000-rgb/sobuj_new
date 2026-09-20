<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ReportStatus;
use App\Enums\ReportTargetType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Report\StoreReportRequest;
use App\Models\Listing;
use App\Models\Report;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

class ReportController extends Controller
{
    /**
     * Files a report against a piece of content or another user. Idempotent per
     * (reporter, target): reporting the same thing twice returns 200 without a second
     * row, so a double-tap can't inflate the moderation queue.
     */
    public function store(StoreReportRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();
        $type = ReportTargetType::from($data['target_type']);

        $target = $type->modelClass()::query()->find($data['target_id']);

        if ($target === null) {
            throw ValidationException::withMessages([
                'target_id' => ['The item you are reporting could not be found.'],
            ]);
        }

        if ((int) $target->getAttribute($type->ownerColumn()) === $user->id) {
            throw ValidationException::withMessages([
                'target_id' => ['You cannot report your own content.'],
            ]);
        }

        $existing = Report::query()
            ->where('reporter_id', $user->id)
            ->where('target_type', $type)
            ->where('target_id', $target->getKey())
            ->exists();

        $message = 'Thanks — our team will review this report.';

        if ($existing) {
            return response()->json(['message' => $message]);
        }

        $report = new Report;
        $report->reporter_id = $user->id;
        $report->target_type = $type;
        $report->target_id = $target->getKey();
        $report->reason = $data['reason'];
        $report->details = $data['details'] ?? null;
        $report->status = ReportStatus::Pending;
        $report->save();

        // A reported listing lands in the existing "flagged first" listing
        // moderation queue too, so staff see it wherever they already look.
        if ($target instanceof Listing && ! $target->is_flagged) {
            $target->update(['is_flagged' => true]);
        }

        return response()->json(['message' => $message], 201);
    }
}
