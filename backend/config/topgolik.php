<?php
return [
    'openligadb' => [
        'leagues' => array_values(array_filter(array_map('trim', explode(',', (string) env('TOPGOLIK_OPENLIGA_LEAGUES', 'bl1,bl2,bl3'))))),
    ],
    'espn' => [
        'base_url' => 'https://site.api.espn.com/apis/site/v2/sports/soccer',
        'leagues' => array_values(array_filter(array_map('trim', explode(',', (string) env('TOPGOLIK_ESPN_LEAGUES', ''))))),
        'timeout' => (int) env('TOPGOLIK_PROVIDER_TIMEOUT', 12),
    ],
];
