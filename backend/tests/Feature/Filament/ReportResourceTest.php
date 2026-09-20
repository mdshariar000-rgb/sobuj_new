<?php

namespace Tests\Feature\Filament;

use App\Enums\ReportStatus;
use App\Enums\ReportTargetType;
use App\Filament\Resources\ReportResource\Pages\ListReports;
use App\Models\Comment;
use App\Models\Report;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ReportResourceTest extends TestCase
{
    use RefreshDatabase;

    private function makeReport(ReportTargetType $type, int $targetId): Report
    {
        $report = new Report;
        $report->reporter_id = User::factory()->create()->id;
        $report->target_type = $type;
        $report->target_id = $targetId;
        $report->reason = 'spam';
        $report->status = ReportStatus::Pending;
        $report->save();

        return $report;
    }

    public function test_non_admins_cannot_open_the_reports_queue(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => false]))
            ->get('/admin/reports')
            ->assertForbidden();
    }

    public function test_admin_sees_pending_reports(): void
    {
        $comment = Comment::factory()->create();
        $report = $this->makeReport(ReportTargetType::Comment, $comment->id);

        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ListReports::class)
            ->assertCanSeeTableRecords([$report]);
    }

    public function test_dismissing_resolves_every_pending_report_on_the_same_item(): void
    {
        $comment = Comment::factory()->create();
        $first = $this->makeReport(ReportTargetType::Comment, $comment->id);
        $second = $this->makeReport(ReportTargetType::Comment, $comment->id);
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        Livewire::test(ListReports::class)
            ->callTableAction('dismiss', $first);

        foreach ([$first, $second] as $report) {
            $report->refresh();
            $this->assertSame(ReportStatus::Dismissed, $report->status);
            $this->assertSame($admin->id, $report->reviewed_by);
        }
    }

    public function test_deleting_reported_content_removes_it_and_resolves_the_reports(): void
    {
        $comment = Comment::factory()->create();
        $report = $this->makeReport(ReportTargetType::Comment, $comment->id);
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ListReports::class)
            ->callTableAction('delete_content', $report);

        $this->assertDatabaseMissing('comments', ['id' => $comment->id]);
        $this->assertSame(ReportStatus::Actioned, $report->fresh()->status);
    }

    public function test_public_legal_pages_are_reachable_without_login_and_show_the_support_email(): void
    {
        $this->get('/privacy')->assertOk()->assertSee('Privacy Policy')->assertSee('Delete account');
        $this->get('/terms')->assertOk()->assertSee('zero tolerance', false);

        Setting::set('support_email', 'help@example.com');

        $this->get('/privacy')->assertSee('help@example.com');
        $this->get('/terms')->assertSee('help@example.com');
    }
}
