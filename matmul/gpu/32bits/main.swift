import Foundation
import MetalPerformanceShaders

func verify(A: [Float], B: [Float], C: [Float], rowsA: Int, colsA: Int, colsB: Int) -> Bool {
    // Converts Swift arrays to C-compatible arrays (Float arrays)
    let aPointer = UnsafeMutablePointer<Float>.allocate(capacity: rowsA * colsA)
    let bPointer = UnsafeMutablePointer<Float>.allocate(capacity: rowsA * colsA)
    let cPointer = UnsafeMutablePointer<Float>.allocate(capacity: rowsA * colsB)

    // Fills pointers with the data from the Swift arrays
    for i in 0..<rowsA * colsA {
        aPointer[i] = Float(A[i])
    }
    for i in 0..<rowsA * colsA {
        bPointer[i] = Float(B[i])
    }
    for i in 0..<rowsA * colsB {
        cPointer[i] = Float(C[i])
    }

    // Call the C verification function
    return verify_matrix_product(aPointer, bPointer, cPointer, 
                              Int32(rowsA), Int32(colsA), Int32(colsB))
}


func main(){
    let argc = CommandLine.argc
    let argv = CommandLine.arguments

    if(argc != 6){
        print("Must be executed as matmul N checkResult checkInstantEnergy checkEnergyOverTime iterations")
        return 
    }
    let N = Int(argv[1])!
    let checkResult = Int(argv[2])!
    let checkInstantEnergy = Int(argv[3])!
    let checkEnergyOverTime = Int(argv[4])!
    let I = Int(argv[5])!

    let rowsA = N
    let columnsA = N
    let rowsB = N
    let columnsB = N

    // Allocate memory for matrix A and B
    let a = UnsafeMutablePointer<Float>.allocate(capacity: rowsA * columnsA)
    let b = UnsafeMutablePointer<Float>.allocate(capacity: rowsB * columnsB)
    let arrayA = UnsafeMutableBufferPointer(start: a, count: rowsA * columnsA)
    let arrayB = UnsafeMutableBufferPointer(start: b, count: rowsB * columnsB)

    // Initialize the matrices with random values between 0 and 1
    for i in 0..<rowsA * columnsA {
        arrayA[i] = Float.random(in: 0..<1)
    }

    for i in 0..<rowsB * columnsB {
        arrayB[i] = Float.random(in: 0..<1)
    }

    if N <= 32 {
        print("Matrix A:")
        for i in 0..<rowsA {
            let row = Array(arrayA[i * columnsA ..< (i + 1) * columnsA])
            print(row.map { String(format: "%.2f", Double($0)) }.joined(separator: " ")) // Convert to Double
        }

        print("\nMatrix B:")
        for i in 0..<rowsB {
            let row = Array(arrayB[i * columnsB ..< (i + 1) * columnsB])
            print(row.map { String(format: "%.2f", Double($0)) }.joined(separator: " ")) // Convert to Double
        }
    }

    // Get the device
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("Error creating device")
        return
    }

    // Create commandQueue
    guard let commandQueue = device.makeCommandQueue() else {
        print("Error creating commandQueue")
        return
    }

    // Create commandBuffer
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
        print("Error creating commandBuffer")
        return
    }

    // Prepare managed buffers
    let rowBytesA = columnsA * MemoryLayout<Float>.stride
    let rowBytesB = columnsB * MemoryLayout<Float>.stride
    let bufferA = device.makeBuffer(bytes: arrayA.baseAddress!, length: rowsA * rowBytesA, options: [.storageModeManaged])!
    let bufferB = device.makeBuffer(bytes: arrayB.baseAddress!, length: rowsB * rowBytesB, options: [.storageModeManaged])!
    let bufferC = device.makeBuffer(length: rowsA * columnsB * MemoryLayout<Float>.stride, options: [.storageModeManaged])!

    // Make matrix descriptors
    let descrA = MPSMatrixDescriptor(rows: rowsA, columns: columnsA, rowBytes: rowBytesA, dataType: .float32)
    let descrB = MPSMatrixDescriptor(rows: rowsB, columns: columnsB, rowBytes: rowBytesB, dataType: .float32)
    let descrC = MPSMatrixDescriptor(rows: rowsA, columns: columnsB, rowBytes: rowsB * MemoryLayout<Float>.stride, dataType: .float32)

    // Make MPSMatrix with buffer and descriptors
    let matrixA = MPSMatrix(buffer: bufferA, descriptor: descrA)
    let matrixB = MPSMatrix(buffer: bufferB, descriptor: descrB)
    let matrixC = MPSMatrix(buffer: bufferC, descriptor: descrC)

    // Make MPSMatrixMultiplication object
    let matMul = MPSMatrixMultiplication(device: device, resultRows: rowsA, resultColumns: columnsB, interiorColumns: columnsA)

    // Encode MPSMatrixMultiplication object into commandBuffer with values
    for _ in 0..<I{
        matMul.encode(commandBuffer: commandBuffer, leftMatrix: matrixA, rightMatrix: matrixB, resultMatrix: matrixC)
    }
    
    // Create a second command buffer for the synchronization (blitEncoder)
    let commandBuffer2 = commandQueue.makeCommandBuffer()!
    let blitEncoder = commandBuffer2.makeBlitCommandEncoder()!

    // Get data back from GPU
    blitEncoder.synchronize(resource: bufferC)
    blitEncoder.endEncoding()

    // Run both buffers
    // Gets energy usage
    if checkInstantEnergy == 1 {
        let ret = startInstantEnergyMeasurement(N: N, presicion: 32)
        if ret == 0 {
            print("Energy measurement started successfully.")
        } else {
            print("Failed to start energy measurement.")
        }
    }
    if checkEnergyOverTime == 1 {
        let ret = startEnergyOverTimeMeasurement(N: N, presicion: 32)
        if ret == 0 {
            print("Energy measurement started successfully.")
        } else {
            print("Failed to start energy measurement.")
        }
    }

    usleep(1000000);
    let startTime = CFAbsoluteTimeGetCurrent() // Gets starting time


    commandBuffer.commit()
    commandBuffer2.commit()

    commandBuffer.waitUntilCompleted()
    commandBuffer2.waitUntilCompleted()

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime // Gets elapsed time
    
    // Stops measuring energy
    if checkInstantEnergy == 1 || checkEnergyOverTime == 1{
        stopEnergyMeasurement()
        print("Energy measurement stopped.")
    }

    let gf = gflops(time: elapsed / 1.0, size: N, iterations: I) // Gets flops

    let elapsed_ = Double(elapsed) / Double(I)

    print("Time: \(Float(elapsed_)) seconds")
    print("Run at \(Int(gf)) GFlops total")

    // Read results
    let resultPointer = bufferC.contents().bindMemory(to: Float.self, capacity: rowsA * columnsB)
    let result = UnsafeBufferPointer(start: resultPointer, count: rowsA * columnsB)

    if N <= 32 {
        print("\nResult Matrix C:")
        
        // Print the result matrix in a readable format
        for i in 0..<rowsA {
            let row = Array(result[i * columnsB ..< (i + 1) * columnsB])
            print(row.map { String(format: "%.2f", Double($0)) }.joined(separator: " "))
        }
    }

    if(checkResult == 1){

        // Verify the result by calling the verify function
        let isCorrect = verify(A: Array(arrayA), B: Array(arrayB), C: Array(result), rowsA: rowsA, colsA: columnsA, colsB: columnsB)
        
        // Print the result of verification
        if isCorrect {
            print("Matrix multiplication verification passed.")
        } else {
            print("Matrix multiplication verification failed.")
        }
    }

    if(checkEnergyOverTime == 0){
       writeTimesToCSV(N: N, elapsedTime: elapsed_, flops: gf, presicion: 32) 
    }
}

main()