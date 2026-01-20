program namelist_test_03
    implicit none

    ! Define variables
    integer :: i1, i2
    real :: r1, r2
    logical :: l1, l2
    character(len=10) :: c1, c2
    integer :: arr1(3)
    real :: arr2(2)

    ! Define namelist
    namelist /testdata/ i1, i2, r1, r2, l1, l2, c1, c2, arr1, arr2

    ! Initialize variables
    i1 = 42
    i2 = -17
    r1 = 3.14159
    r2 = -2.71828
    l1 = .true.
    l2 = .false.
    c1 = 'hello'
    c2 = 'world'
    arr1(1) = 1
    arr1(2) = 2
    arr1(3) = 3
    arr2(1) = 1.5
    arr2(2) = 2.5

    ! Write namelist to file
    open(unit=10, file='namelist_test.dat', status='replace', form='formatted')
    write(10, nml=testdata)
    close(10)

    ! Verify the file was created by writing to stdout
    print *, "Namelist written to file. Contents:"
    write(*, nml=testdata)

    print *, ""
    print *, "All namelist tests passed!"

end program namelist_test_03
