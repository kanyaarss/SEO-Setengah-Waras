<?php
$url = [
"https://www.google.com",
"https://www.instagram.com",
"https://www.youtube.com",
"https://www.facebook.com",
"https://www.tiktok.com",
];

$bunvisGG = $url[array_rand($url)];

header("Location: $bunvisGG");
exit();
?>
