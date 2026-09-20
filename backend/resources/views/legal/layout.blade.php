<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title') — Agro Hub</title>
    <style>
        :root { color-scheme: light; }
        body {
            margin: 0;
            background: #f7faf7;
            color: #1b1f1c;
            font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }
        header { background: #183a2e; color: #fff; padding: 28px 20px; }
        header div, main { max-width: 760px; margin: 0 auto; }
        header .brand { font-weight: 700; font-size: 1.1rem; letter-spacing: .02em; color: #8df8b5; }
        header h1 { margin: 6px 0 0; font-size: 1.7rem; }
        main { padding: 28px 20px 64px; }
        h2 { margin: 32px 0 8px; font-size: 1.15rem; color: #006d3f; }
        p, li { margin: 0 0 10px; }
        ul { padding-left: 22px; }
        .updated { color: #717974; font-size: .9rem; }
        a { color: #006d3f; }
        footer { max-width: 760px; margin: 0 auto; padding: 0 20px 40px; color: #717974; font-size: .9rem; }
    </style>
</head>
<body>
    <header>
        <div>
            <div class="brand">Agro Hub</div>
            <h1>@yield('title')</h1>
        </div>
    </header>
    <main>
        <p class="updated">Last updated: {{ $updated }}</p>
        @yield('content')
    </main>
    <footer>
        <a href="{{ url('/privacy') }}">Privacy Policy</a> &middot; <a href="{{ url('/terms') }}">Terms of Use</a>
        @if ($supportEmail)
            &middot; <a href="mailto:{{ $supportEmail }}">{{ $supportEmail }}</a>
        @endif
    </footer>
</body>
</html>
