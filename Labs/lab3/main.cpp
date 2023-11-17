//
//  main.cpp
//  lab3
//
//  Created by Всеволод Донченко on 17.11.2023.
//

#include <iostream>
#include <omp.h>

using namespace std;

int main(int argc, const char * argv[]) {
    #pragma omp parallel
    printf("Hello from thread %d, nthreads %d\n", omp_get_thread_num(), omp_get_num_threads());
    return 0;
}
