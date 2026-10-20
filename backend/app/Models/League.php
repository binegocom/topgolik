<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

final class League extends Model
{
    protected $guarded = [];
    protected $casts = ['synced_at' => 'immutable_datetime'];
}
