import sys
import json


if __name__ == "__main__":
    video_config = sys.argv[1]
    video_settings_path = sys.argv[2]

    with open(video_config) as f:
        content = json.load(f)
        content = {f'"{k}"': f'"{v}"' for k, v in content.items()}
    try:
        with open(video_settings_path, "r") as f:
            pairs = [line.lower().strip().split() for line in f.readlines()]
            old_content = {pair[0]: pair[1] for pair in pairs if len(pair) == 2}
    except FileNotFoundError:
        old_content = {}
        print("File not found. Creating new file...")

    new_content = old_content | content
    new_content = {k: v for k, v in new_content.items()}

    with open(video_settings_path, "w+") as f:
        f.writelines(
            [
                "video.cfg\n",
                "{\n"
            ] + [f"\t{k}\t\t{v}\n" for k, v in new_content.items()] + [
                "}\n",
            ]
        )
    print("Updated " + video_settings_path)