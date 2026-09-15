<?php

namespace App\Enums;

enum AiMessageRole: string
{
    case User = 'user';
    case Assistant = 'assistant';
}
