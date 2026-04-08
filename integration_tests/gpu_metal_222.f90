! Test nested struct with allocatable members in do concurrent.
! Exercises the buffer-count fix for nested struct decomposition.
! Pattern: wrapper_t has non-allocatable inner_t member; inner_t has
! allocatable v(:).  The kernel reads from arr(i)%data%v directly (testing
! buffer decomposition through non-allocatable struct members).
! The submodule function get_w on a simple_t creates a VLA workspace,
! which triggers the buffer-index assertion if buffer counting is wrong.
module gpu_metal_222_m
  implicit none
  type :: inner_t
    real, allocatable :: v(:)
  end type
  type :: wrapper_t
    type(inner_t) :: data
  end type
  type :: simple_t
    real, allocatable :: w(:)
  end type
  interface
    pure module function get_w(self) result(r)
      type(simple_t), intent(in) :: self
      real, allocatable :: r(:)
    end function
  end interface
end module

submodule(gpu_metal_222_m) gpu_metal_222_s
  implicit none
contains
  module procedure get_w
    allocate(r(size(self%w)))
    r = self%w
  end procedure
end submodule

program gpu_metal_222
  use gpu_metal_222_m
  implicit none
  integer, parameter :: n = 4
  type(wrapper_t) :: arr(n)
  type(simple_t) :: src(n)
  real :: results(n)
  integer :: i

  do i = 1, n
    allocate(arr(i)%data%v(2))
    arr(i)%data%v = [real(i), real(i+1)]
    allocate(src(i)%w(2))
    src(i)%w = [real(i*10), real(i*10 + 1)]
  end do

  do concurrent(i=1:n)
    results(i) = arr(i)%data%v(1) + g(src(i))
  end do

  ! Expected: arr(i)%data%v(1) = i, g(src(i)) = sum([i*10, i*10+1]) = 20*i+1
  do i = 1, n
    if (abs(results(i) - real(i + 20*i + 1)) > 1e-6) error stop
  end do
  print *, "PASS"

contains
  pure function g(x) result(r)
    type(simple_t), intent(in) :: x
    real :: r
    associate(s => sum(get_w(x)))
      r = s
    end associate
  end function
end program
