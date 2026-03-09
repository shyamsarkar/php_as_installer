<?php
// Sample index.php — replace with your actual application
// These credentials match what INSTALL.bat sets up automatically
$host     = 'localhost';
$username = 'appuser';   // DB_USER in INSTALL.bat
$password = 'secret123'; // DB_PASS in INSTALL.bat
$database = 'myapp';     // DB_NAME in INSTALL.bat

$conn = mysqli_connect($host, $username, $password, $database);

if (!$conn) {
    die("MySQL connection failed: " . mysqli_connect_error());
}
?>
<!DOCTYPE html>
<html>
<head><title>PHP App</title></head>
<body>
    <h1>PHP App is Running!</h1>
    <p>MySQL Status: <strong style="color:green">Connected ✓</strong></p>
    <p>Database: <strong><?php echo $database; ?></strong></p>
    <p>PHP Version: <?php echo phpversion(); ?></p>
</body>
</html>