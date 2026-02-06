<?php
$ip = $_SERVER['SERVER_ADDR'] ?? gethostbyname(gethostname());
?>
<!DOCTYPE html>
<html>
<head>
<title>StreamLine v1</title>
</head>
<body style="font-family: Arial; background:#f2f2f2; text-align:center; padding-top:80px;">
<h1>Welcome to Streamline - v1</h1>
<p>Server IP: <strong><?php echo $ip; ?></strong></p>
</body>
</html>
