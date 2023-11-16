/usr/local/mpich/bin/mpic++ main.cpp -o mpi

if [ $# -ge 1 ]; then
    /usr/local/mpich/bin/mpirun -n $1 ./mpi
else
    /usr/local/mpich/bin/mpirun -n 1 ./mpi
fi
