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
    'openfootball' => [
        // Verified against football.json's public 2024-25 directory; availability varies by season.
        'leagues' => [
            'tr.1' => ['country' => 'Turkey', 'timezone' => 'Europe/Istanbul'],
            'en.1' => ['country' => 'England', 'timezone' => 'Europe/London'],
            'en.2' => ['country' => 'England', 'timezone' => 'Europe/London'],
            'en.3' => ['country' => 'England', 'timezone' => 'Europe/London'],
            'en.4' => ['country' => 'England', 'timezone' => 'Europe/London'],
            'de.1' => ['country' => 'Germany', 'timezone' => 'Europe/Berlin'],
            'de.2' => ['country' => 'Germany', 'timezone' => 'Europe/Berlin'],
            'es.1' => ['country' => 'Spain', 'timezone' => 'Europe/Madrid'],
            'es.2' => ['country' => 'Spain', 'timezone' => 'Europe/Madrid'],
            'it.1' => ['country' => 'Italy', 'timezone' => 'Europe/Rome'],
            'it.2' => ['country' => 'Italy', 'timezone' => 'Europe/Rome'],
            'fr.1' => ['country' => 'France', 'timezone' => 'Europe/Paris'],
            'fr.2' => ['country' => 'France', 'timezone' => 'Europe/Paris'],
            'at.1' => ['country' => 'Austria', 'timezone' => 'Europe/Vienna'],
            'at.2' => ['country' => 'Austria', 'timezone' => 'Europe/Vienna'],
            'be.1' => ['country' => 'Belgium', 'timezone' => 'Europe/Brussels'],
            'nl.1' => ['country' => 'Netherlands', 'timezone' => 'Europe/Amsterdam'],
            'pt.1' => ['country' => 'Portugal', 'timezone' => 'Europe/Lisbon'],
            'sco.1' => ['country' => 'Scotland', 'timezone' => 'Europe/London'],
            'gr.1' => ['country' => 'Greece', 'timezone' => 'Europe/Athens'],
            'au.1' => ['country' => 'Australia', 'timezone' => 'Australia/Sydney'],
            'mx.1' => ['country' => 'Mexico', 'timezone' => 'America/Mexico_City'],
            'eg.1' => ['country' => 'Egypt', 'timezone' => 'Africa/Cairo'],
            'ma.1' => ['country' => 'Morocco', 'timezone' => 'Africa/Casablanca'],
            'uefa.cl' => ['country' => 'Europe', 'timezone' => 'Europe/Zurich'],
        ],
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
