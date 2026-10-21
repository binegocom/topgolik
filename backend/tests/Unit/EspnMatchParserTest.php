<?php
namespace Tests\Unit;

use App\Data\EspnMatchParser;
use PHPUnit\Framework\TestCase;

final class EspnMatchParserTest extends TestCase
{
    private function fixture(): array
    {
        // Synthetic values are exclusively a test fixture, never runtime content.
        return ['events' => [[
            'id' => '44', 'date' => '2026-10-21T20:00Z',
            'status' => ['type' => ['state' => 'in', 'shortDetail' => '52\'']],
            'competitions' => [['competitors' => [
                ['homeAway' => 'away', 'score' => '1', 'team' => ['id' => '7', 'displayName' => 'Away FC']],
                ['homeAway' => 'home', 'score' => '2', 'team' => ['id' => '9', 'displayName' => 'Home FC']],
            ]]],
        ]]];
    }

    public function test_maps_home_and_away_independently_of_source_order(): void
    {
        $match = (new EspnMatchParser)->parse($this->fixture())[0];
        self::assertSame('9', $match['home']['external_id']);
        self::assertSame(2, $match['home']['score']);
        self::assertSame('7', $match['away']['external_id']);
        self::assertSame('live', $match['status']);
    }

    public function test_uses_source_direct_logo_url_when_logo_array_is_missing(): void
    {
        $payload = $this->fixture();
        $payload['events'][0]['competitions'][0]['competitors'][1]['team']['logo']
            = 'https://a.espncdn.com/i/teamlogos/soccer/500/9.png';

        $match = (new EspnMatchParser)->parse($payload)[0];
        self::assertSame(
            'https://a.espncdn.com/i/teamlogos/soccer/500/9.png',
            $match['home']['logo_url'],
        );
    }

    public function test_invalid_event_is_skipped_without_inventing_data(): void
    {
        self::assertSame([], (new EspnMatchParser)->parse(['events' => [['id' => '3']]]));
    }
}
