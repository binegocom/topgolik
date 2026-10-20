<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

final class FootballMatch extends Model
{
    protected $table = 'football_matches';
    protected $guarded = [];
    protected $casts = [
        'starts_at' => 'immutable_datetime',
        'synced_at' => 'immutable_datetime',
        'home_score' => 'integer',
        'away_score' => 'integer',
    ];
    public function league(): BelongsTo { return $this->belongsTo(League::class); }
    public function homeTeam(): BelongsTo { return $this->belongsTo(Team::class, 'home_team_id'); }
    public function awayTeam(): BelongsTo { return $this->belongsTo(Team::class, 'away_team_id'); }
}
