#!/usr/bin/env python3
"""
Upload.am OpenVPN Config Generator with Rule-Based Split Tunneling.
Supports:
  - telegram: Only Telegram official IP CIDRs
  - full: All internet traffic
  - custom: Custom domains and IP ranges
  - exclude: Full VPN excluding specified domains/IPs (via net_gateway)
"""

import sys
import os
import argparse
import socket
import re

TELEGRAM_CIDRS = [
    ("91.108.4.0", "255.255.252.0"),
    ("91.108.8.0", "255.255.252.0"),
    ("91.108.12.0", "255.255.252.0"),
    ("91.108.16.0", "255.255.252.0"),
    ("91.108.20.0", "255.255.252.0"),
    ("91.108.56.0", "255.255.252.0"),
    ("91.105.192.0", "255.255.254.0"),
    ("149.154.160.0", "255.255.240.0"),
    ("185.76.151.0", "255.255.255.0"),
]

def cidr_to_netmask(cidr: int) -> str:
    mask = (0xffffffff >> (32 - cidr)) << (32 - cidr)
    return f"{(mask >> 24) & 0xff}.{(mask >> 16) & 0xff}.{(mask >> 8) & 0xff}.{mask & 0xff}"

def parse_target(item: str):
    item = item.strip()
    if not item:
        return None
    if "/" in item:
        ip, prefix = item.split("/", 1)
        return (ip.strip(), cidr_to_netmask(int(prefix.strip())))
    elif re.match(r"^\d+\.\d+\.\d+\.\d+$", item):
        return (item, "255.255.255.255")
    else:
        # Domain name
        return (item, "255.255.255.255")

def transform_ovpn(input_text: str, mode: str, targets=None) -> str:
    lines = input_text.splitlines()
    clean_lines = []
    
    # Remove existing route-nopull, block-outside-dns, or conflicting routes
    for line in lines:
        s = line.strip()
        if s.startswith("route-nopull") or s.startswith("block-outside-dns") or s.startswith("setenv opt block-outside-dns"):
            continue
        clean_lines.append(line)

    route_block = []

    if mode == "telegram":
        route_block.append("\n# Mode: Telegram Split Tunneling (No default gateway override)")
        route_block.append("route-nopull")
        for net, mask in TELEGRAM_CIDRS:
            route_block.append(f"route {net} {mask}")

    elif mode == "custom":
        route_block.append("\n# Mode: Custom Whitelist (Only specified destinations)")
        route_block.append("route-nopull")
        if targets:
            for t in targets:
                parsed = parse_target(t)
                if parsed:
                    route_block.append(f"route {parsed[0]} {parsed[1]}")

    elif mode == "exclude":
        route_block.append("\n# Mode: Exclude / Inverse (Route all traffic EXCEPT specified targets)")
        if targets:
            for t in targets:
                parsed = parse_target(t)
                if parsed:
                    route_block.append(f"route {parsed[0]} {parsed[1]} net_gateway")

    elif mode == "full":
        route_block.append("\n# Mode: Full VPN (All system traffic)")
        # Default OpenVPN pulls redirect-gateway def1 from server

    # Insert route_block before certificates/keys if present, or append
    ca_index = -1
    for idx, l in enumerate(clean_lines):
        if l.strip().startswith("<ca>"):
            ca_index = idx
            break

    if ca_index != -1:
        result = clean_lines[:ca_index] + route_block + [""] + clean_lines[ca_index:]
    else:
        result = clean_lines + route_block

    return "\n".join(result) + "\n"

def main():
    parser = argparse.ArgumentParser(description="Customize OpenVPN split-routing rules.")
    parser.add_argument("--input", "-i", required=True, help="Input .ovpn profile path")
    parser.add_argument("--output", "-o", required=True, help="Output .ovpn profile path")
    parser.add_argument("--mode", "-m", choices=["telegram", "full", "custom", "exclude"], default="telegram",
                        help="Routing mode")
    parser.add_argument("--targets", "-t", nargs="*", default=[],
                        help="Domains or IP/CIDRs for custom/exclude mode")

    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        content = f.read()

    new_content = transform_ovpn(content, args.mode, args.targets)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"Generated {args.output} [mode={args.mode}]")

if __name__ == "__main__":
    main()
