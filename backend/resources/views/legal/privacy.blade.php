@extends('legal.layout')

@section('title', 'Privacy Policy')

@section('content')
    <p>Agro Hub is a community app for growers to swap and sell plants, join local groups, and attend events. This policy explains what we collect, why, who we share it with, and how you can delete it.</p>

    <h2>What we collect</h2>
    <ul>
        <li><strong>Account details:</strong> your name, email address, and password (stored only as a one-way hash), plus optional profile details such as username, bio, phone number, growing interests, and profile and cover photos.</li>
        <li><strong>Location:</strong> the location you give us when you register or post. We store it on our servers, but other users only ever see a randomized approximation (offset by roughly 500&ndash;1000 metres) &mdash; never your exact coordinates. You can hide even that from other users in your profile settings.</li>
        <li><strong>Content you create:</strong> listings, photos, posts, comments, events, group messages, and swap-offer messages. Photos are re-encoded on upload and their embedded metadata (including GPS tags) is removed.</li>
        <li><strong>Device information:</strong> a push-notification token for your device, its platform, and the app version, so we can deliver notifications you've asked for.</li>
    </ul>

    <h2>How we use it</h2>
    <p>To run the app: showing nearby listings, enabling swaps and chat, delivering notifications, and keeping the community safe. We do not sell your personal information and do not use it for advertising or cross-app tracking.</p>

    <h2>Who we share it with</h2>
    <ul>
        <li><strong>Google (Firebase Cloud Messaging):</strong> your device's push token and the notification text, to deliver push notifications.</li>
        <li><strong>Other users:</strong> whatever you choose to post or list, together with your name and public profile.</li>
    </ul>

    <h2>Safety and moderation</h2>
    <p>You can report any post, comment, listing, event, group, message, or user from within the app, and block any user. Blocked users can't see your content or contact you. Reports are reviewed by our team, and content or accounts that break our <a href="{{ url('/terms') }}">Terms of Use</a> are removed.</p>

    <h2>Security</h2>
    <p>All traffic between the app and our servers is encrypted (HTTPS). Your sign-in session is kept in your device's secure storage.</p>

    <h2>Your choices and deleting your data</h2>
    <p>You can edit your profile at any time. You can delete your account inside the app under <strong>Profile &rarr; Delete account</strong>. Deleting your account permanently removes your profile, listings, posts, comments, events, messages, uploaded photos, and device tokens. Groups you created that still have other members are handed to another member rather than deleted.</p>

    <h2>Children</h2>
    <p>Agro Hub is not intended for children under 13, and we do not knowingly collect their information.</p>

    <h2>Changes and contact</h2>
    <p>We may update this policy and will change the date above when we do.
        @if ($supportEmail)
            Questions or requests: <a href="mailto:{{ $supportEmail }}">{{ $supportEmail }}</a>.
        @endif
    </p>
@endsection
