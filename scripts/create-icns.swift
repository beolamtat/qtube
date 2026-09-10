import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: create-icns.swift iconset-directory output.icns")
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianBytes(_ value: UInt32) -> Data {
    var encoded = value.bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

var body = Data()
for (type, filename) in chunks {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    body.append(type.data(using: .ascii)!)
    body.append(bigEndianBytes(UInt32(png.count + 8)))
    body.append(png)
}

var result = Data("icns".utf8)
result.append(bigEndianBytes(UInt32(body.count + 8)))
result.append(body)
try result.write(to: output, options: .atomic)
