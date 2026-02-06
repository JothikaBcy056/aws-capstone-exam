<?php
$ip = $_SERVER['SERVER_ADDR'] ?? gethostbyname(gethostname());
?>
<!DOCTYPE html>
<html>
<head>
<title>StreamLine v2</title>
</head>
<body style="font-family: Arial; background:#e0f7ff; text-align:center; padding-top:80px;">
<h1>Welcome to StreamLine - v2 [New Feature]</h1>
<p>Server IP: <strong><?php echo $ip; ?></strong></p>
</body>
</html>
