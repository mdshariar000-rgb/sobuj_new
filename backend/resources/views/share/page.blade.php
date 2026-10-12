<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ? $title.' — Shobuj' : 'Shobuj' }}</title>
    <meta property="og:site_name" content="Shobuj">
    <meta property="og:title" content="{{ $title ?? 'Shobuj' }}">
    <meta property="og:description" content="{{ $subtitle ?? 'Grow. Share. Sustain.' }}">
    @if ($imageUrl)
        <meta property="og:image" content="{{ $imageUrl }}">
    @endif
    <style>
        :root { color-scheme: light; }
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            background: #f7faf7;
            color: #1b1f1c;
            font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }
        header { width: 100%; background: #183a2e; color: #fff; text-align: center; padding: 28px 16px 72px; box-sizing: border-box; }
        .brand { font-weight: 700; font-size: 1.4rem; }
        .slogan { color: #8df8b5; margin-top: 4px; }
        .card { width: calc(100% - 32px); max-width: 420px; margin-top: -48px; background: #fff; border-radius: 20px; box-shadow: 0 8px 24px rgba(0, 0, 0, .08); overflow: hidden; }
        .card img { display: block; width: 100%; aspect-ratio: 4 / 3; object-fit: cover; background: #e6efe8; }
        .card img.round { width: 112px; height: 112px; aspect-ratio: auto; border-radius: 50%; margin: 24px auto 0; }
        .body { padding: 20px; text-align: center; }
        h1 { margin: 0; font-size: 1.3rem; }
        .sub { color: #5d6660; margin-top: 4px; }
        .cta { margin-top: 20px; color: #5d6660; font-size: .95rem; }
        .buttons { display: flex; flex-direction: column; gap: 10px; margin-top: 12px; }
        .buttons a { display: block; padding: 13px; border-radius: 999px; background: #006d3f; color: #fff; font-weight: 600; text-decoration: none; }
        .buttons a.alt { background: #e6efe8; color: #183a2e; }
    </style>
</head>
<body>
    <header>
        <div class="brand">Shobuj</div>
        <div class="slogan">Grow. Share. Sustain.</div>
    </header>
    <div class="card">
        @if ($imageUrl)
            <img src="{{ $imageUrl }}" alt="" @class(['round' => $round ?? false])>
        @endif
        <div class="body">
            @if ($title)
                <h1>{{ $title }}</h1>
                @if ($subtitle)
                    <div class="sub">{{ $subtitle }}</div>
                @endif
                <div class="cta">Open it in the Shobuj app.</div>
            @else
                <h1>{{ $fallback }}</h1>
                <div class="cta">Find plants, seeds, groups and events near you in the Shobuj app.</div>
            @endif
            @if ($appStoreUrl || $androidUrl)
                <div class="buttons">
                    @if ($appStoreUrl)
                        <a href="{{ $appStoreUrl }}">Get it for iPhone</a>
                    @endif
                    @if ($androidUrl)
                        <a href="{{ $androidUrl }}" @class(['alt' => (bool) $appStoreUrl])>Get it for Android</a>
                    @endif
                </div>
            @endif
        </div>
    </div>
</body>
</html>
