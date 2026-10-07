import argparse
from find_test_strings import ZStringDecoder


def parse_num(value: str) -> int:
    return int(value, 0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode Z-machine string at packed address")
    parser.add_argument("packed", type=parse_num, help="Packed address (e.g. 0xA3F5)")
    parser.add_argument("--story", default="zork1.z3", help="Path to story file")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show zchar decode trace")
    args = parser.parse_args()

    with open(args.story, "rb") as story_file:
        data = story_file.read()

    decoder = ZStringDecoder(data)
    byte_addr = args.packed * 2
    text, byte_len = decoder.decode(byte_addr, verbose=args.verbose)

    print(f"packed=0x{args.packed:04X}")
    print(f"byte_addr=0x{byte_addr:05X}")
    print(f"encoded_len={byte_len}")
    print("decoded=")
    print(text)


if __name__ == "__main__":
    main()
