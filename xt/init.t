use Test::More tests => 5;
use xt::Test;

my $dir = "xt/YT1";
rmtree($dir);
mkdir($dir) or die;
chdir($dir) or die;

run "yt init";

ok -d($YEAR), "$YEAR directory exists";
ok -e("conf/customer.yaml"), "conf/customer.yaml exists";
ok -e("conf/project.yaml"), "conf/project.yaml exists";
ok -e("conf/tags.yaml"), "conf/tags.yaml exists";
ok -e("conf/yt.yaml"), "conf/yt.yaml exists";

chdir($HOME) or die;
rmtree($dir) or die;
