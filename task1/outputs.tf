output "vpc_id" {
  value = digitalocean_vpc.main.id
}

output "droplet_ip" {
  value = digitalocean_droplet.node.ipv4_address
}

output "firewall_id" {
  value = digitalocean_firewall.main.id
}

output "bucket_name" {
  value = digitalocean_spaces_bucket.main.name
}
