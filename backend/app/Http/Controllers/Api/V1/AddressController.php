<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\AddressLookupService;
use App\Services\PostcodeAddressService;
use App\Support\UkAddress;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/**
 * Address suggestions for the app's address form (sign-up and "Your
 * address"). No auth: sign-up happens before there's an account. Rate
 * limited per IP in routes/api.php.
 */
class AddressController extends Controller
{
    public function suggest(Request $request, AddressLookupService $lookup): JsonResponse
    {
        $data = $request->validate(['q' => ['required', 'string', 'min:3', 'max:100']]);

        try {
            return response()->json(['data' => $lookup->suggest($data['q'])]);
        } catch (RuntimeException $e) {
            report($e);

            // The app falls back to typing the address in by hand.
            return response()->json(['message' => 'Address suggestions are unavailable right now.'], 503);
        }
    }

    /**
     * Every address at a postcode, for "type your postcode, pick your
     * address". 404 for a postcode that doesn't exist; 503 when lookups
     * aren't set up or are down, and the app then asks for the street.
     */
    public function postcode(Request $request, PostcodeAddressService $lookup): JsonResponse
    {
        $request->merge(['postcode' => UkAddress::normalisePostcode($request->input('postcode'))]);
        $data = $request->validate([
            'postcode' => ['required', 'string', 'regex:'.UkAddress::POSTCODE_PATTERN],
        ], ['postcode.regex' => 'Enter a full UK postcode, e.g. LS6 3AA.']);

        try {
            $addresses = $lookup->lookup($data['postcode']);
        } catch (RuntimeException $e) {
            if ($lookup->isConfigured()) {
                report($e);
            }

            return response()->json(['message' => 'Address lookup is unavailable right now.'], 503);
        }

        if ($addresses === null) {
            return response()->json(['message' => "We couldn't find that postcode. Please check it."], 404);
        }

        return response()->json(['data' => $addresses]);
    }
}
