<?php

namespace App\Services;

use Exception;

/** The Google/Apple token was rejected; the message is safe to show. */
class InvalidSocialToken extends Exception {}
