<?php
namespace App\Contracts;

interface ScoreProvider
{
    public function id(): string;
    /** @return array<string, mixed> */
    public function scoreboard(string $league, string $date): array;
}
