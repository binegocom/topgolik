<?php
return [
    // Product-curated search suggestions. These are labels only, never fabricated team records.
    'featured_teams' => [
        ['label' => 'AmedSpor', 'aliases' => ['AmedSpor', 'Amedspor', 'Amed Sportif Faaliyetler', 'Amed Sportif']],
        ['label' => 'Vanspor FK', 'aliases' => ['Vanspor FK', 'Vanspor', 'Van Spor FK', 'Vanspor Futbol Kulübü']],
        ['label' => 'Mardin 1969 Spor', 'aliases' => ['Mardin 1969 Spor', 'Mardin 1969 SK', 'Mardin 1969']],
        ['label' => 'Batman Petrol Spor', 'aliases' => ['Batman Petrol Spor', 'Batman Petrolspor', 'Batman Petrol Spor Kulübü']],
        ['label' => 'Muş Spor Kulübü', 'aliases' => ['Muş Spor Kulübü', 'Muşspor', 'Muş Spor', 'Mus Spor']],
        ['label' => '12 Bingölspor', 'aliases' => ['12 Bingölspor', '12 Bingolspor', '12 Bingöl Spor']],
        ['label' => 'Galatasaray', 'aliases' => ['Galatasaray', 'Galatasaray SK']],
        ['label' => 'Fenerbahçe', 'aliases' => ['Fenerbahçe', 'Fenerbahce', 'Fenerbahçe SK']],
        ['label' => 'Beşiktaş', 'aliases' => ['Beşiktaş', 'Besiktas', 'Beşiktaş JK']],
    ],
    'openligadb' => [
        // No overlapping 'bl1' by default: ESPN already imports Germany first division.
        'leagues' => array_values(array_filter(array_map('trim', explode(',', (string) env('TOPGOLIK_OPENLIGA_LEAGUES', 'bl2,bl3'))))),
    ],
    'espn' => [
        'base_url' => 'https://site.api.espn.com/apis/site/v2/sports/soccer',
        'leagues' => array_values(array_filter(array_map('trim', explode(',', (string) env('TOPGOLIK_ESPN_LEAGUES', ''))))),
        'timeout' => (int) env('TOPGOLIK_PROVIDER_TIMEOUT', 12),
    ],
];
