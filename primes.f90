program primes
integer :: i, x, j, d, z, k, l 
do l=2,1000
    i=l
    print*,i
    do k=2,l-1
    do while (i/k*k==i) 
        i=i/k
        print *,"    ", k
    end do 
    end do
end do
end program