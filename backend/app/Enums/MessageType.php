<?php

namespace App\Enums;

enum MessageType: string
{
    case Text = 'text';
    case SystemEvent = 'system_event';
}
