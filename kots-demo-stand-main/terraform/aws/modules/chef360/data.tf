data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

// cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]