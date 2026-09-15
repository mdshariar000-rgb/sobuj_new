<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * Thrown when an uploaded file passes form validation (correct mime/extension) but
 * cannot actually be decoded as an image — e.g. a truncated or corrupted upload.
 */
class ImageProcessingException extends RuntimeException
{
    //
}
