module gpu_metal_241_types_m
  implicit none
  type :: inner_t
    real, allocatable :: vals(:)
  end type
  type :: pair_t
    type(inner_t) :: a
  end type
  type :: batch_t
    type(pair_t), allocatable :: pairs(:)
  end type
contains
  elemental function make_pair(a) result(p)
    type(inner_t), intent(in) :: a
    type(pair_t) :: p
    p%a = a
  end function
  pure function make_batch(pairs) result(bt)
    type(pair_t), intent(in) :: pairs(:)
    type(batch_t) :: bt
    bt%pairs = pairs
  end function
end module

program gpu_metal_241
  use gpu_metal_241_types_m
  implicit none
  integer, parameter :: n = 2
  type(inner_t) :: x(1, n)
  type(batch_t) :: res(n)
  integer :: i

  do i = 1, n
    allocate(x(1, i)%vals(1))
    x(1, i)%vals(1) = real(i)
  end do

  do concurrent(i = 1:n)
    res(i) = make_batch(make_pair(x(:, i)))
  end do

  if (size(res(1)%pairs) /= 1) error stop
  if (size(res(2)%pairs) /= 1) error stop
  print *, "OK"
end program
