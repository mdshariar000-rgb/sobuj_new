@extends('legal.layout')

@section('title', 'Terms of Use')

@section('content')
    <p>By creating an account or using Agro Hub you agree to these terms.</p>

    <h2>Acceptable content and behavior</h2>
    <p>Agro Hub has <strong>zero tolerance for objectionable content and abusive users</strong>. You may not post, list, send, or share anything that is:</p>
    <ul>
        <li>hateful, harassing, threatening, or discriminatory;</li>
        <li>sexually explicit, graphically violent, or otherwise offensive;</li>
        <li>spam, a scam, or deliberately misleading;</li>
        <li>illegal, including the sale of banned or invasive plant species or protected wildlife;</li>
        <li>an infringement of someone else's rights or privacy.</li>
    </ul>

    <h2>Reporting and blocking</h2>
    <p>Every post, comment, listing, event, group, chat message, and user profile has a <strong>Report</strong> option, and you can <strong>Block</strong> any user. We review reports and act on them promptly, aiming to do so within 24 hours. Content that breaks these terms is removed, and accounts responsible may be suspended or permanently banned without notice.</p>

    <h2>Your content</h2>
    <p>You keep ownership of what you post, and you give Agro Hub permission to display it to other users as part of the service. Groups, posts, comments, and events you create are visible to other members or the community feed depending on where you post them, alongside your name.</p>

    <h2>Marketplace and swaps</h2>
    <p>Agro Hub connects growers; it is not a party to any swap, sale, or gift, does not handle payment for goods, and does not guarantee the quality, safety, or legality of anything listed. Meet in public places where possible, and comply with local plant-movement and biosecurity rules.</p>

    <h2>Suspension and deleting your account</h2>
    <p>We may suspend or remove accounts that break these terms. You can delete your account at any time in the app under <strong>Profile &rarr; Delete account</strong>.</p>

    <h2>Contact</h2>
    <p>
        @if ($supportEmail)
            Questions, reports, or appeals: <a href="mailto:{{ $supportEmail }}">{{ $supportEmail }}</a>.
        @else
            Use the in-app Report option for any concern.
        @endif
    </p>
@endsection
