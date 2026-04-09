program gpu_metal_239
  implicit none

  type :: point_t
    integer :: x
  end type

  integer, parameter :: n = 4
  type(point_t) :: results(2, n)
  integer :: i

  do concurrent(i = 1:n)
    results(:, i) = fill(i)
  end do

  do i = 1, n
    print *, results(1,i)%x, results(2,i)%x
    if (results(1,i)%x /= i) error stop
    if (results(2,i)%x /= i * 10) error stop
  end do

contains

  pure function fill(v) result(arr)
    integer, intent(in) :: v
    type(point_t), allocatable :: arr(:)
    allocate(arr(2))
    arr(1) = point_t(v)
    arr(2) = point_t(v * 10)
  end function

end program
