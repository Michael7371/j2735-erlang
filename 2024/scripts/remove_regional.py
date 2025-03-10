import os

file_name = input("enter erl file name: ")
file_path = f"../examples/{file_name}.src"

print(file_path)


if os.path.exists(file_path):
    with open(file_path, "r") as f:
        for l in f.readlines():
            print(l)
else:
    print(f"{file_path} does not exist! Exiting")
