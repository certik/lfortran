! Test: elemental function call with struct argument that has an
! allocatable array member, called with an array section inside
! do concurrent (GPU Metal offload). The elemental function returns
! a struct so subroutine_from_function converts it to a SubroutineCall,
! exercising the Metal codegen elemental struct-member decomposition.
program gpu_metal_204
  implicit none

  type :: pair_t
    real, allocatable :: v(:)
  end type

  type :: val_t
    real :: x
  end type

  integer, parameter :: m = 3, n = 4
  type(pair_t) :: dat(m, n)
  real :: sums(n)
  integer :: i, j

  do j = 1, n
    do i = 1, m
      dat(i,j) = pair_t(v=[real :: i + (j-1)*m])
    end do
  end do

  do concurrent(i = 1:n)
    sums(i) = total(extract(dat(:,i)))
  end do

  ! Expected: sums(1) = 1+2+3 = 6
  !           sums(2) = 4+5+6 = 15
  !           sums(3) = 7+8+9 = 24
  !           sums(4) = 10+11+12 = 33
  if (abs(sums(1) - 6.0) > 1e-6) error stop
  if (abs(sums(2) - 15.0) > 1e-6) error stop
  if (abs(sums(3) - 24.0) > 1e-6) error stop
  if (abs(sums(4) - 33.0) > 1e-6) error stop
  print *, "ok"

contains

  elemental function extract(x) result(r)
    type(pair_t), intent(in) :: x
    type(val_t) :: r
    r%x = x%v(1)
  end function

  pure function total(arr) result(s)
    type(val_t), intent(in) :: arr(:)
    real :: s
    integer :: j
    s = 0.0
    do j = 1, size(arr)
      s = s + arr(j)%x
    end do
  end function

end program
