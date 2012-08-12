<?php
$content_for_layout = json_encode(array("status" => 200,
	"task"=> array("id" => 23, "name" => "Wizards of Oz", "children" => array())
));

header("Pragma: no-cache");
header("Cache-Control: no-store, no-cache, max-age=0, must-revalidate");
header('Content-Type: text/x-json');
header("X-JSON: ".$content_for_layout);

echo $content_for_layout;
?>