<?php

namespace App\Http\Requests\Report;

use App\Enums\ReportReason;
use App\Enums\ReportTargetType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Existence of the target is checked in ReportController rather than here, since
     * the table to look in depends on target_type.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'target_type' => ['required', Rule::enum(ReportTargetType::class)],
            'target_id' => ['required', 'integer', 'min:1'],
            'reason' => ['required', Rule::enum(ReportReason::class)],
            'details' => ['nullable', 'string', 'max:500'],
        ];
    }
}
