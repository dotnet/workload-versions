param ([Parameter(Mandatory=$true)] [string] $dropPath)

$combinedHash = [byte[]]@()
$algorithm = [System.Security.Cryptography.SHA256]::Create()

$files = Get-ChildItem -Path $dropPath | Sort-Object
$null = $files | Get-Content -Encoding Byte -Raw | ForEach-Object { $combinedHash += $algorithm.ComputeHash($_) }
[System.BitConverter]::ToString($algorithm.ComputeHash([byte[]]$combinedHash)).Replace('-','')


# $dropPath = 'D:\Workspace\Workload.VSDrop.emsdk.8.0-8.0.100.components'

# For SHA512, 512 is the hash size. Shifting it to the right 3 makes it 64.
# $hashSize = $algorithm.HashSize -shr 3

# $file = $files | Select-Object -First 1
# $byteArray = Get-Content -Path $file.FullName -AsByteStream -Raw
# $hash = $algorithm.ComputeHash($byteArray)


# 61ABDFE6D4BF8F7E5A0184B469DBAB846124E9A4E0649F3365A0DD311C61738845F1CF4F898E9028108549B413F30F2680F805E80FE58F2A2FD5C99ACF55EA29
# 61ABDFE6D4BF8F7E5A0184B469DBAB846124E9A4E0649F3365A0DD311C61738845F1CF4F898E9028108549B413F30F2680F805E80FE58F2A2FD5C99ACF55EA29

# 61ABDFE6D4BF8F7E5A0184B469DBAB846124E9A4E0649F3365A0DD311C61738845F1CF4F898E9028108549B413F30F2680F805E80FE58F2A2FD5C99ACF55EA29

# 1E3EA4FE202394037253F57436A6EAD5DE1359792B618B9072014A98563A30FB
# 1E3EA4FE202394037253F57436A6EAD5DE1359792B618B9072014A98563A30FB

# 1E3EA4FE202394037253F57436A6EAD5DE1359792B618B9072014A98563A30FB