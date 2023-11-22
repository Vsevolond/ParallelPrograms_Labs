#include <iostream>
#include "mpi.h"
#include <vector>
#include <tuple>
#include <chrono>

using namespace std;

#define N 2048
#define eps 0.00001
#define FINISH_TAG 1
#define VECTOR_TAG 2
#define TAU_TAG 3

double tau = 0.1 / N;

class Matrix;

// MARK: - VECTOR

class Vector {
    
private:
    vector<double> data;
    
public:
    int size;
    
    Vector nextBy(Matrix matrixA, Vector vectorX, Vector vectorB, double tau);
    double valueBy(Matrix matrixA, Vector vectorB);
    
    Vector(int n) {
        size = n;
        data = vector<double>(n);
    }
    
    Vector(double *arr, int n) {
        size = n;
        data = vector<double>(n);
        for (int i = 0; i < n; i++) {
            set(i, arr[i]);
        }
    }
    
    double get(int x) {
        return data.at(x);
    }
    
    void set(int x, double value) {
        data.at(x) = value;
    }
    
    void fill() {
        for (int i = 0; i < size; i++) {
            set(i, size + 1);
        }
    }
    
    Vector substraction(Vector vector) {
        Vector newVector(size);

        for (int i = 0; i < size; i++) {
            double first = get(i);
            double second = vector.get(i);
            
            newVector.set(i, first - second);
        }

        return newVector;
    }
    
    double multiply(Vector vector) {
        double result = 0.0;
        
        for (int i = 0; i < size; i++) {
            double first = get(i);
            double second = vector.get(i);
            
            result += first * second;
        }
        
        return result;
    }
    
    double mod() {
        double result = 0.0;
        
        for (int i = 0; i < size; i++) {
            double value = get(i);
            result += value * value;
        }
        
        return sqrt(result);
    }
    
    Vector operator * (double x) {
        Vector newVector(size);
        
        for (int i = 0; i < size; i++) {
            double oldValue = get(i);
            newVector.set(i, oldValue * x);
        }
        
        return newVector;
    }
    
    void operator += (Vector vector) {
        Vector newVector(size + vector.size);

        for (int i = 0; i < size; i++) {
            newVector.set(i, get(i));
        }
        for (int i = 0; i < vector.size; i++) {
            newVector.set(i + size, vector.get(i));
        }
        
        *this = newVector;
    }
    
    Vector splitFor(int process, int tasks) {
        int count = size / tasks;
        Vector newVector(count);
        
        for (int i = 0; i < count; i++) {
            int index = process * count + i;
            newVector.set(i, get(index));
        }
        
        return newVector;
    }
    
    double* toArray() {
        double *arr = new double[size];
        for (int i = 0; i < size; i++) {
            arr[i] = get(i);
        }
        return arr;
    }
    
    void print() {
        for (int i = 0; i < size; i++) {
            cout << get(i) << " ";
        }
        cout << endl;
    }
};

// MARK: - MATRIX

class Matrix {

private:
    vector<Vector> data;
    
public:
    int rows, columns;
    
    Matrix(int n, int m) {
        rows = n;
        columns = m;
        for (int i = 0; i < n; i++) {
            data.push_back(Vector(m));
        }
    }
    
    double get(int x, int y) {
        return data.at(x).get(y);
    }
    
    void set(int x, int y, double value) {
        data.at(x).set(y, value);
    }
    
    Matrix splitFor(int process, int tasks) {
        int lines = rows / tasks;
        Matrix newMatrix(lines, columns);
        
        for (int i = 0; i < lines; i++) {
            for (int j = 0; j < columns; j++) {

                int row = process * lines + i;
                double value = get(row, j);
                newMatrix.set(i, j, value);
            }
        }
        
        return newMatrix;
    }
    
    Vector multiply(Vector vector) {
        Vector result(rows);
        
        for (int i = 0; i < rows; i++) {
            Vector row = data.at(i);
            double value = row.multiply(vector);
            result.set(i, value);
        }
        
        return result;
    }
    
    void fill() {
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < columns; j++) {
                if (j == i) {
                    set(i, j, 2.0);
                } else {
                    set(i, j, 1.0);
                }
            }
        }
    }
};

// MARK: - FUNCTIONS

Vector Vector::nextBy(Matrix matrixA, Vector vectorX, Vector vectorB, double tau) {
    return substraction(
        matrixA.multiply(vectorX).substraction(vectorB) * tau
    );
}

double Vector::valueBy(Matrix matrixA, Vector vectorB) {
    double first = matrixA.multiply(*this).substraction(vectorB).mod();
    double second = vectorB.mod();
    
    return first / second;
}

void iterationSLAUSolution(Matrix matrixA, Vector vectorX, Vector vectorB, int process, int tasks) {
    Matrix splitedMatrixA = matrixA.splitFor(process, tasks);
    Vector splitedVectorB = vectorB.splitFor(process, tasks);
    Vector splitedVectorX = vectorX.splitFor(process, tasks);
    
    bool finish = false;
    while (!finish) {
        Vector newVectorX = splitedVectorX.nextBy(splitedMatrixA, vectorX, vectorB, tau);
        splitedVectorX = newVectorX;
        MPI_Barrier(MPI_COMM_WORLD);
        
        if (process == 0) {
            
            for (int i = 1; i < tasks; i++) {
                int size = splitedVectorX.size;
                MPI_Status status;
                double *arr = new double[size];
                MPI_Recv(arr, size, MPI_DOUBLE, i, VECTOR_TAG, MPI_COMM_WORLD, &status);
                newVectorX += Vector(arr, size);
                delete [] arr;
            }
            
            vectorX = newVectorX;
            
            double lastValue = vectorX.valueBy(matrixA, vectorB);
            double newValue = newVectorX.valueBy(matrixA, vectorB);
            
            finish = (newValue < eps);
            
            for (int i = 1; i < tasks; i++) {
                MPI_Send(&finish, 1, MPI_CXX_BOOL, i, FINISH_TAG, MPI_COMM_WORLD);
            }
            
            if (finish) {
//                newVectorX.print();
            } else {
                if (newValue > lastValue) {
                    tau = -tau;
                }

                double *arr = vectorX.toArray();
                int size = vectorX.size;
                for (int i = 1; i < tasks; i++) {
                    MPI_Send(arr, size, MPI_DOUBLE, i, VECTOR_TAG, MPI_COMM_WORLD);
                    MPI_Send(&tau, 1, MPI_DOUBLE, i, TAU_TAG, MPI_COMM_WORLD);
                }
                delete [] arr;
            }
            
            
        } else {
            
            double *arr = newVectorX.toArray();
            MPI_Send(arr, newVectorX.size, MPI_DOUBLE, 0, VECTOR_TAG, MPI_COMM_WORLD);
            delete [] arr;
            
            MPI_Status status;
            MPI_Recv(&finish, 1, MPI_CXX_BOOL, 0, FINISH_TAG, MPI_COMM_WORLD, &status);
            
            if (!finish) {
                int size = vectorX.size;
                status = MPI_Status();
                double *arr = new double[size];
                MPI_Recv(arr, size, MPI_DOUBLE, 0, VECTOR_TAG, MPI_COMM_WORLD, &status);
                vectorX = Vector(arr, size);
                delete [] arr;
                
                status = MPI_Status();
                MPI_Recv(&tau, 1, MPI_DOUBLE, 0, TAU_TAG, MPI_COMM_WORLD, &status);
            }
        }
    }
}


// MARK: - MAIN

int main(int argc, char * argv[]) {
    int process, tasks;

    MPI_Init(&argc, &argv);

    MPI_Comm_size(MPI_COMM_WORLD, &tasks);
    MPI_Comm_rank(MPI_COMM_WORLD, &process);
    
    Matrix matrixA(N, N);
    matrixA.fill();
    
    Vector vectorB(N);
    vectorB.fill();
    
    Vector vectorX(N);
    
    chrono::time_point<chrono::system_clock> start = chrono::system_clock::now();
    
    iterationSLAUSolution(matrixA, vectorX, vectorB, process, tasks);
    
    chrono::time_point<chrono::system_clock> end = chrono::system_clock::now();
    
    chrono::duration<double> seconds = end - start;
    double time = static_cast<double>(seconds.count());
    
    if (process == 0) {
        cout << time << endl;
    }

    MPI_Finalize();
}
